#!/bin/bash

NUM_SEQS=10
WORKING_DIR=`pwd`

# Loop over all user-supplied input directories that 
# contain alignment files
for VAR in "$@"
do
    echo $VAR
    # Find all alignent files in the directory, create a subirectory for each
    # split it into multiple files for MACSE alignment, submit a macse job
    for ALIGN in `find $VAR -name "*unique.pick.align"`
    do
        # full path to alignment file for creating a functioning
        # soft link
        ALIGN="$(cd "$(dirname "$ALIGN")"; pwd)/$(basename "$ALIGN")"
        MACSE_DIR=${ALIGN/.unique.pick.align/}
        mkdir -p $MACSE_DIR
        cd $MACSE_DIR
        ln -s $ALIGN .

        # reassign just the alignment name to the ALIGN var and split
        # the fasta file into roughly equal chunks
        ALIGN=`basename $ALIGN`

        # Parfait!!! below I run split fasta files and capture the number of files 
        # created from the stderr stream
        NUM_FASTA_FILES=$("$WORKING_DIR"/split_fasta.pl --length $NUM_SEQS $ALIGN 2>&1 | grep Created | awk '{ print $2 }')
        cp -v "$WORKING_DIR"/3_MacseAlign.job .

        # Before we run MACSE the dots introduced into the alignment by
        # Mothur need to be replaced by dashes
        for FASTA in `find $MACSE_DIR -name "*.fasta"`
        do
            sed -i 's/\./-/g' $FASTA
        done

        # Submit MACSE alignments to the queue
        cp -v "$WORKING_DIR"/3_MacseAlign.job .
        sed -i "s/MAX_TASKS/$NUM_FASTA_FILES/" 3_MacseAlign.job
        JOB_NAME=`echo $ALIGN | awk -F '.' '{ print $1 }'`
        sed -i "s/JOB_NAME/$JOB_NAME/" 3_MacseAlign.job
        qsub 3_MacseAlign.job

        # Return to the working directory and move on to process
        # the next alignment
        cd $WORKING_DIR
    done
done
