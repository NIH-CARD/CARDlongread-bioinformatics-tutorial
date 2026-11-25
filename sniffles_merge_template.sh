#!/bin/bash

#SBATCH --cpus-per-task=16
#SBATCH --mem=16g
#SBATCH --mail-type=BEGIN,TIME_LIMIT_90,END
#SBATCH --time=1:00:00
#SBATCH --gres=lscratch:20

# get array job number for spooling subjobs
# N=${SLURM_ARRAY_TASK_ID}
# tab delimited file with list of samples and flow cells in columns 1 and 2
# SAMPLE_SHEET='/data/CARDPB/data/KOLF_mutant_sequencing/SCRIPTS/KOLF_mutant_sequencing_SAMPLE_FLOWCELL_FIXED_NAMES_101226.tsv'
# SAMPLE_ID=$(sed -n ${N}p $SAMPLE_SHEET | cut -f 1)
# FLOWCELL=$(sed -n ${N}p $SAMPLE_SHEET | cut -f 2)

# debugging output to slurm script
# echo "Job Array #${N}"
# echo "SAMPLE_ID ${SAMPLE_ID}"
# echo "FLOWCELL ${FLOWCELL}"

# load sniffles version 2.7.5
ml sniffles/2.7.5
BASE_DIR=/data/CARDPB/data/cohort

ulimit -n 32768 -u 32768

# make snf output directory and parents if necessary
# mkdir -p ${BASE_DIR}/Sniffles_UNPHASED_per_sample/snf

# BAM=${BASE_DIR}/MAPPED_BAM_BQ_FILTERED_HG38/${SAMPLE_ID}/${SAMPLE_ID}_${FLOWCELL}.sorted_minimap2_bq10_filtered.bam
# echo $BAM
# run sniffles with 16 threads
# sniffles --phase --allow-overwrite -t 16 --input $BAM --snf ${BASE_DIR}/Sniffles_UNPHASED_per_sample/snf/${SAMPLE_ID}.snf

# combine VCFs
COHORT_NAME=cohort
ls ${BASE_DIR}/Sniffles_UNPHASED_per_sample/snf/* > ${BASE_DIR}/Sniffles_UNPHASED_per_sample/${COHORT_NAME}_SNIFFLES_samples.tsv
mkdir -p ${BASE_DIR}/Sniffles_UNPHASED_per_sample/vcf
OUTPUT_VCF=${COHORT_NAME}_sniffles_merged.vcf
sniffles --threads 32 --input ${BASE_DIR}/Sniffles_UNPHASED_per_sample/${COHORT_NAME}_SNIFFLES_samples.tsv --vcf ${BASE_DIR}/Sniffles_UNPHASED_per_sample/vcf/${OUTPUT_VCF}

# split merged VCF back into harmonized per sample VCFs
ml samtools
bcftools +split ${BASE_DIR}/Sniffles_UNPHASED_per_sample/vcf/${OUTPUT_VCF} -o ${BASE_DIR}/Sniffles_UNPHASED_per_sample/vcf/${COHORT_NAME}_merged_sample_split
