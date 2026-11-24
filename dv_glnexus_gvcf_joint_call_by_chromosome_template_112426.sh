#!/usr/bin/bash

#SBATCH --partition=norm
#SBATCH --cpus-per-task=56
#SBATCH --mem=200g
#SBATCH --mail-type=BEGIN,TIME_LIMIT_90,END
#SBATCH --time=8:00:00
#SBATCH --gres=lscratch:500

# define configuration variables
# GLNEXUS_CONFIG=/home/mollerabg/glnexus_clair3_config/clair3.yml
# default thread and memory limits
GLNEXUS_THREAD_LIMIT=40
GLNEXUS_MEM_GBYTES_LIMIT=120
# limit bcftools and bgzip to I/O speed
BCFTOOLS_THREADS=60
BGZIP_THREADS=60
# set output merge destination
# OUTPUT_GLNEXUS_MERGE_PATH=

# parallelize by chromosome
# make sure to make array
CHROMOSOMES=($(cut -f1 /data/mollerabg/GRCh38_per_chromosome_beds/GRCh38_CARD_ref.bed))
N=${SLURM_ARRAY_TASK_ID}
CURRENT_CHROMOSOME=${CHROMOSOMES[$((N-1))]}

# debug output
echo "CURRENT CHROMOSOME: ${CURRENT_CHROMOSOME}"

# load necessary modules on Biowulf
# need jemalloc for proper memory allocation
module load jemalloc bcftools glnexus

# remove existing glnexus DB in working directory
# rm -rf GLnexus.DB

# set high enough (well more than enough) open files and processes
ulimit -Sn 65536 -u 65536

# inject correct Biowulf jemalloc into glnexus executable ahead of runtime
export LD_PRELOAD=/usr/local/apps/jemalloc/5.3.0/lib/libjemalloc.so

BASE_DIR=/data/CARDPB/data/cohort

# make output folder with each per chromosome GLnexus joint called VCF
mkdir -p ${BASE_DIR}/GLNEXUS_DEEPVARIANT_JOINT_CALL/PER_CHROMOSOME

# ==========================================
# 1. DEFINE AND CREATE SCRATCH PATHS (CRUCIAL FIX)
# ==========================================
SCRATCH_DIR="/lscratch/${SLURM_JOB_ID}/task_${SLURM_ARRAY_TASK_ID}"
mkdir -p "${SCRATCH_DIR}/slices"
# mkdir -p "${SCRATCH_DIR}/GLnexusDB"

# Create a clean text file list of your target gVCF inputs
GVCF_LIST="${SCRATCH_DIR}/gvcf_input_list.txt"
printf "%s\n" ${BASE_DIR}/GLNEXUS_DEEPVARIANT_JOINT_CALL/GVCF_INPUTS/*.g.vcf.gz > "${GVCF_LIST}"

# ==========================================
# 2. DEFINE THE EXTRACTION FUNCTION
# ==========================================
# This function extracts and indexes a single file slice
run_slice_extraction() {
    local gvcf="$1"
    local chrom="$2"
    local s_dir="$3"
    local sample_name=$(basename "${gvcf}" .g.vcf.gz)
    local slice_path="${s_dir}/slices/${sample_name}.${chrom}.g.vcf.gz"
    
    # Process slice using 2 threads locally
    bcftools view --threads 2 -r "${chrom}" -O z -o "${slice_path}" "${gvcf}"
    bcftools index --threads 2 --tbi "${slice_path}"
}
export -f run_slice_extraction
# export -f bcftools

# ==========================================
# 3. RUN VIA GNU PARALLEL (CLEAN & EXPLICIT)
# ==========================================
module load parallel

# {} represents the gVCF path streamed from printf.
# The other variables are passed explicitly as normal arguments at the end.
printf "%s\n" ${BASE_DIR}/GLNEXUS_DEEPVARIANT_JOINT_CALL/GVCF_INPUTS/*.g.vcf.gz | \
  parallel -j 24 run_slice_extraction {} "${CURRENT_CHROMOSOME}" "${SCRATCH_DIR}"


# ==========================================
# 4. DISCOVER FRESH SLICES AND RUN GLNEXUS
# ==========================================
GLNEXUS_INPUTS=("${SCRATCH_DIR}/slices"/*.g.vcf.gz)

# run glnexus with appropriate parameters
# set upper limits on threads and RAM, specifically for glnexus
# formerly used /data/mollerabg/glnexus/glnexus_cli
glnexus_cli --config DeepVariantWGS --dir ${SCRATCH_DIR}/GLnexusDB \
--bed /data/mollerabg/GRCh38_per_chromosome_beds/${CURRENT_CHROMOSOME}.bed \
"${GLNEXUS_INPUTS[@]}"  --threads ${GLNEXUS_THREAD_LIMIT} --mem-gbytes ${GLNEXUS_MEM_GBYTES_LIMIT} | \
bcftools view --threads ${BCFTOOLS_THREADS} - | bgzip -@ ${BGZIP_THREADS} -c \
> ${BASE_DIR}/GLNEXUS_DEEPVARIANT_JOINT_CALL/PER_CHROMOSOME/cohort_dv_glnexus_gvcf_joint_call_${CURRENT_CHROMOSOME}.vcf.gz

# gvcf source before: ${BASE_DIR}/PARABRICKS_DEEPVARIANT_UNPHASED/*/*.g.vcf.gz

# index output
bcftools index --threads ${BCFTOOLS_THREADS} ${BASE_DIR}/GLNEXUS_DEEPVARIANT_JOINT_CALL/PER_CHROMOSOME/cohort_dv_glnexus_gvcf_joint_call_${CURRENT_CHROMOSOME}.vcf.gz
# note time taken for merge to complete
