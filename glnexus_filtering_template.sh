#!/bin/bash

#SBATCH --cpus-per-task=8
#SBATCH --mem=8g
#SBATCH --mail-type=BEGIN,TIME_LIMIT_90,END
#SBATCH --time=2:00:00
#SBATCH --gres=lscratch:20

# set reference genome and joint call name
REFERENCE_GENOME=/data/CARDPB/resources/hg38/GCA_000001405.15_GRCh38_no_alt_analysis_set.fa
JOINT_CALL_NAME=cohort_glnexus_merge

# run normalization, set IDs, set low quality genotypes to missing, set high quality genotypes to 0/0, fill in AC/AN/AF tags again, and then export
bcftools norm -m -any -f ${REFERENCE_GENOME} ${JOINT_CALL_NAME}.vcf.gz -Ou | \
bcftools annotate --set-id '%CHROM:%POS:%REF:%ALT' - -O u | \
bcftools +setGT - -O u -- -t q -n . -i 'FMT/DP<10 || FMT/GQ<20' | \
bcftools +setGT - -Ou -- -t q -n 0 -i 'GT="miss" && FMT/DP>=10 && FMT/GQ>=20' | \
bcftools +fill-tags - -O u -- -t AC,AN,AF | \
bcftools view -c 1 - -O z -o ${JOINT_CALL_NAME}_norm_ref_missing_filtered.vcf.gz

