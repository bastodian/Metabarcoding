#!/bin/bash

for i in R3/Index7/*_R1_*gz R3/Index13/*_R1_*gz R3/Index14/*_R1_*gz R3/Index16/*_R1_*gz
do
    DIR=`dirname $i`
    FWD_FQ=`basename $i`
    BARCODES=`find $DIR -name "*txt"`
    echo $DIR
    echo $FWD_FQ
    echo $BARCODES
    cd $DIR
    pwd
    echo $FWD_FQ ${FWD_FQ/_R1_/_R2_} `basename $BARCODES`
    qsub -S /bin/sh \
        -q mThC.q \
        -pe mthread 16 \
        -cwd \
        -j y \
        -N "`basename ${BARCODES/.txt/}`" \
        -o "`basename ${BARCODES/.txt/}`"".log" \
        -m abe \
        /pool/genomics/bentlageb/Metabarcoding/PrepareCuracao.sh $FWD_FQ ${FWD_FQ/_R1_/_R2_} `basename $BARCODES` 16
    cd /pool/genomics/bentlageb/Metabarcoding
done
