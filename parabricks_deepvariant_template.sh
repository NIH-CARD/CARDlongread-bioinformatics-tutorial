#!/bin/bash

#SBATCH --partition=niacard
#SBATCH --cpus-per-task=56
#SBATCH --mem=200g
#SBATCH --mail-type=BEGIN,TIME_LIMIT_90,END
#SBATCH --time=1:00:00
#SBATCH --gres=lscratch:300,gpu:h200:1

N=${SLURM_ARRAY_TASK_ID}
# note this has a different structure from a typical sample sheet
# list of subsetted BAM files
SAMPLE_SHEET='/data/CARDPB/data/cohort/SCRIPTS/cohort_sample_list.txt'
# N=${SLURM_ARRAY_TASK_ID}

SAMPLE_ID=$(sed -n ${N}p $SAMPLE_SHEET | cut -f 1)
# FLOWCELL=$(sed -n ${N}p $SAMPLE_SHEET | cut -f 2)

# debugging output
echo "Job Array #${N}"
echo "SAMPLE_ID ${SAMPLE_ID}"
# echo "FLOWCELL ${FLOWCELL}"

# specify base directory
BASE_DIR=/data/CARDPB/data/cohort

# module load singularity
# module load deepvariant/1.10.0
module load parabricks/4.7.1

# make DEEPVARIANT output folder and parents if necessary
mkdir -p ${BASE_DIR}/PARABRICKS_DEEPVARIANT_UNPHASED

# use per sample per chromosome subsetted BAMs
BAM_IN=$(ls ${BASE_DIR}/MAPPED_BAM_MERGED_BQ_FILTERED/${SAMPLE_ID}.sorted_minimap2_bq10_filtered.bam)
# BAM_RG_IN=$(basename ${BASE_DIR}/MAPPED_BAM_BQ_FILTERED/${SAMPLE_ID}/${SAMPLE_ID}_${FLOWCELL}.sorted_minimap2_bq10_filtered.bam)
BAM_RG_IN="${SAMPLE_ID}_${FLOWCELL}.rg.bam"
OUT_FOLDER=${BASE_DIR}/PARABRICKS_DEEPVARIANT_UNPHASED/${SAMPLE_ID}
SAMPLE_PREFIX=${SAMPLE_ID}
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

# add read group tag with sample name and ont technology to BAM header, put in local scratch.
module load samtools
samtools addreplacerg \
-@ 40 \
-r "@RG\tID:${SAMPLE_ID}\tSM:${SAMPLE_ID}\tPL:ONT" \
-o /lscratch/${SLURM_JOB_ID}/${BAM_RG_IN} \
${BAM_IN}

samtools index --threads 40 /lscratch/${SLURM_JOB_ID}/${BAM_RG_IN}

# removed docker image described above. now use built-in biowulf module
# old intermediate results folder: ${OUT_FOLDER}/intermediate_results_dir
pbrun deepvariant \
--mode ont \
--ref /data/CARDPB/resources/hg38/GCA_000001405.15_GRCh38_no_alt_analysis_set.fa \
--in-bam /lscratch/${SLURM_JOB_ID}/${BAM_RG_IN} \
--out-variants ${OUT_FOLDER}/${SAMPLE_PREFIX}.g.vcf.gz \
--gvcf \
--tmp-dir /lscratch/${SLURM_JOB_ID}/ \
--logfile ${OUT_FOLDER}/logs

# make output folder accessible to everybody
chmod -R 775 ${OUT_FOLDER}
# __________________________________________________________________________________________________
# INDEX UNPHASED BAM
# module load samtools
# samtools index ${OUT_FOLDER}/${SAMPLE_PREFIX}.haplotagged.bam
