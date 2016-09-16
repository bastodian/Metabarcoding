#!/bin/bash

# This submission script finds all paired gzip compressed fastq files in a user-supplied
# directory. It then submits one jobs per fastq file containing multiple metabarcode samples.
# This script calls 1_PrepData.sh that performs basic QC, assembly of paired reads and 
# extracts all samples from the fastq.
#
# Dependency: 1_PrepData.sh
#
# ./1_PrepData.job THREADS

THREADS=$1
WORKING_DIR=`pwd`

for i in `find ./ -name "*_R1_*gz"`
do
    DIR=`dirname $i`
    FWD_FQ=`basename $i`
    BARCODES=`find $DIR -name "*txt"`
    cd $DIR
    pwd
    echo $FWD_FQ ${FWD_FQ/_R1_/_R2_} `basename $BARCODES`
    qsub -S /bin/sh \
        -q mThC.q \
        -pe mthread $THREADS \
        -cwd \
        -j y \
        -N "`basename ${BARCODES/.txt/}`" \
        -o "`basename ${BARCODES/.txt/}`"".log" \
        -m abe \
        "$WORKING_DIR"/1_PrepData.sh $FWD_FQ ${FWD_FQ/_R1_/_R2_} `basename $BARCODES` $THREADS
    cd $WORKING_DIR
done
