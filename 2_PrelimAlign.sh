#!/bin/bash

# This submission script finds all fasta files generated in step 1
# of this pipeline. The user has to provide the directory containing
# these fasta files as the 1st argument to the script. Further,
# the 2nd argument must be a reference alignment, as mothur is
# used to align all fasta files against this reference. Post-alignment,
# duplicate and chimeric sequences are removed.
#
# ./2_PrelimAlign.job DirectoryContainingFastas TemplateAlignment

DATA_DIR=$1
TEMPLATE="$(cd "$(dirname "$2")"; pwd)/$(basename "$2")"
WORKING_DIR=`pwd`

for i in $DATA_DIR
do
    echo $i
    for j in `find $i -name "*fasta"`
    do
        echo $j
        FASTA=`basename $j`
        if [ "unmatched.fasta" != "$FASTA" ]
        then
            echo $FASTA
            DIR=$i
            cd $DIR
            pwd
            qsub -S /bin/sh \
                -q lThC.q \
                -cwd \
                -j y \
                -N "`basename ${j/.fasta/}`" \
                -o "`basename ${j/.fasta/}`"".log" \
                -m abe \
                "$WORKING_DIR"/2_PrelimAlign.job $FASTA $TEMPLATE
            cd $WORKING_DIR
        fi
    done
done
