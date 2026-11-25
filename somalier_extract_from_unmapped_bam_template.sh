#!/usr/bin/bash
#SBATCH --cpus-per-task=56
#SBATCH --mem=150g
#SBATCH --mail-type=BEGIN,TIME_LIMIT_90,END
#SBATCH --time=8:00:00
#SBATCH --gres=lscratch:300

#NEED TO CHANGE HERE
BASE_DIR=/data/CARDPB/data/cohort
# ALL_LONGREAD_SOMALIER_CHECK
#DEST_DIR=/data/CARD_AUX/LRS_temp/UAB
SAMPLE_SHEET='/data/CARDPB/data/cohort/SCRIPTS/cohort_sample_flowcell.tsv'
REFERENCE_GENOME='/data/CARDPB/resources/hg38/GCA_000001405.15_GRCh38_no_alt_analysis_set.fa'

N=${SLURM_ARRAY_TASK_ID}

SAMPLE_ID=$(sed -n ${N}p $SAMPLE_SHEET | cut -f 1)
FLOWCELL=$(sed -n ${N}p $SAMPLE_SHEET | cut -f 2)

# debugging output for logs
echo "Job Array #${N}"
echo "SAMPLE_ID ${SAMPLE_ID}"
echo "FLOWCELL ${FLOWCELL}"

# load modules
module load samtools nanopack minimap2

# make output directory if necessary
# mkdir -p ${BASE_DIR}/MAPPED_BAM_BQ_FILTERED_HG38
# mkdir -p ${BASE_DIR}/MAPPED_BAM_BQ_FILTERED_HG38/${SAMPLE_ID}

# increase available processes and files
ulimit -n 32768 -u 32768
# clean fail with pipefail
set -euo pipefail

OUT_BAM=${SAMPLE_ID}_${FLOWCELL}.sorted_minimap2_bq10_filtered.bam
# make scratch folder for aligned bam
mkdir -p /lscratch/${SLURM_JOB_ID}/aligned_bam

# first convert UBAM to fastq, then filter by Q score, then map to hg38, then convert to bam, then sort
samtools fastq -@ 16 ${BASE_DIR}/ONT_UBAM/${SAMPLE_ID}_${FLOWCELL}*.bam | \
chopper -t 16 -q 10 | \
minimap2 -ax map-ont ${REFERENCE_GENOME} - -k 17 -y -K 10g -t 50 --MD --eqx | \
samtools sort -@ 50 -m 1200M -T /lscratch/${SLURM_JOB_ID}/sort_tmp --write-index \
-o /lscratch/${SLURM_JOB_ID}/aligned_bam/${OUT_BAM}##idx##/lscratch/${SLURM_JOB_ID}/aligned_bam/${OUT_BAM}.bai
# > ${BASE_DIR}/MAPPED_BAM_BQ_FILTERED_HG38/${SAMPLE_ID}/${SAMPLE_ID}_${FLOWCELL}.sorted_minimap2_bq10_filtered.bam

# make output mapped BAM index
# samtools index --threads 600 ${BASE_DIR}/MAPPED_BAM_BQ_FILTERED_HG38/${SAMPLE_ID}/${SAMPLE_ID}_${FLOWCELL}.sorted_minimap2_bq10_filtered.bam

# run cramino
# BAM=${SAMPLE_ID}/${SAMPLE_ID}_${FLOWCELL}.sorted_minimap2_bq10_filtered.bam

# cramino -t 56 --reference ${REFERENCE_GENOME} ${BASE_DIR}/MAPPED_BAM_BQ_FILTERED_HG38/${BAM} 
# > ${BASE_DIR}/MAPPED_BAM_BQ_FILTERED_HG38/${BAM}_cramino_QC.txt
# initialize somalier
source /data/mollerabg/mymamba/etc/profile.d/mamba.sh
mamba activate somalier

# make cohort parent directory if necessary
mkdir -p ${BASE_DIR}/${COHORT}/FLOWCELL_SOMALIER_EXTRACT
# give somalier sample name given it's not in RG tag in BAM
export SOMALIER_SAMPLE_NAME="${SAMPLE_ID}_${FLOWCELL}"
# extract genotypes with somalier
somalier extract -s /data/mollerabg/somalier/sites.hg38.vcf.gz \
-f ${REFERENCE_GENOME} \
/lscratch/${SLURM_JOB_ID}/aligned_bam/${OUT_BAM} \
-d ${BASE_DIR}/${COHORT}/FLOWCELL_SOMALIER_EXTRACT
