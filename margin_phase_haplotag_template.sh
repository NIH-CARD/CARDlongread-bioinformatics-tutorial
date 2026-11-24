#!/bin/bash

#SBATCH --partition=norm
#SBATCH --cpus-per-task=56
#SBATCH --mem=100g
#SBATCH --mail-type=BEGIN,TIME_LIMIT_90,END
#SBATCH --time=6:00:00
#SBATCH --gres=lscratch:50

N=${SLURM_ARRAY_TASK_ID}
# note this has a different structure from a typical sample sheet
# list of subsetted BAM files
SAMPLE_SHEET='/data/CARDPB/data/cohort/SCRIPTS/cohort_SAMPLE_FLOWCELL.tsv'
# N=${SLURM_ARRAY_TASK_ID}

SAMPLE_ID=$(sed -n ${N}p $SAMPLE_SHEET | cut -f 1)
FLOWCELL=$(sed -n ${N}p $SAMPLE_SHEET | cut -f 2)

# debugging output
echo "Job Array #${N}"
echo "SAMPLE_ID ${SAMPLE_ID}"
echo "FLOWCELL ${FLOWCELL}"

# specify base directory
BASE_DIR=/data/CARDPB/data/KOLF_mutant_cohort

# module load singularity
# module load deepvariant/1.10.0

# make marginphased output folder and parents if necessary
mkdir -p ${BASE_DIR}/MARGIN_HAPLOTAGGED_PHASED

# use per sample per chromosome subsetted BAMs
BAM_IN=$(ls ${BASE_DIR}/MAPPED_BAM_BQ_FILTERED/${SAMPLE_ID}/${SAMPLE_ID}_${FLOWCELL}.sorted_minimap2_bq10_filtered.bam)
OUT_FOLDER=${BASE_DIR}/MARGIN_HAPLOTAGGED_PHASED/${SAMPLE_ID}
SAMPLE_PREFIX=${SAMPLE_ID}
# REFERENCE_GENOME=/data/CARDPB/data/KOLF_mutant_sequencing/REFERENCE/KOLF2.1Jv1.0.hap1.fa
REFERENCE_GENOME=/data/CARDPB/resources/hg38/GCA_000001405.15_GRCh38_no_alt_analysis_set.fa
# deepvariant docker image version
# BIN_VERSION="1.8.0-gpu"

# make output directory and parent if necessary
mkdir -p ${OUT_FOLDER}
# cp -r $PEPPER_DATA/* .
# use local singularity/docker image
# docker://google/deepvariant:"${BIN_VERSION}-gpu" \
# change to local instance of docker image
# singularity run --nv -B /usr/lib/locale/:/usr/lib/locale/ \
# /data/mollerabg/deepvariant/deepvariant_1.8.0-gpu.sif \

# increase user limits in case you want to increase the number of shards/parallelization of the program
ulimit -n 32768 -u 32768

${BASE_DIR}/margin/bin/margin phase \
${BAM_IN} \
${REFERENCE_GENOME} \
${BASE_DIR}/PARABRICKS_DEEPVARIANT_UNPHASED/${GLNEXUS_JOINT_CALL_NAME}/${SAMPLE_ID}.vcf.gz \
${BASE_DIR}/margin/params/phase/allParams.haplotag.ont-r104q20.json \
-o ${OUT_FOLDER}/${SAMPLE_PREFIX} \
-t 56
# --skipPhasedVCF

# index output BAM
module load samtools
samtools index --threads ${SLURM_CPUS_PER_TASK} ${OUT_FOLDER}/${SAMPLE_PREFIX}.haplotagged.bam

# index output VCF
bgzip -@ ${SLURM_CPUS_PER_TASK} ${OUT_FOLDER}/${SAMPLE_PREFIX}.phased.vcf && tabix -p vcf ${OUT_FOLDER}/${SAMPLE_PREFIX}.phased.vcf.gz

# make output folder accessible to everybody
chmod -R 775 ${OUT_FOLDER}
# __________________________________________________________________________________________________
# INDEX UNPHASED BAM
# module load samtools
# samtools index ${OUT_FOLDER}/${SAMPLE_PREFIX}.haplotagged.bam
