#!/bin/bash

# QUICK USAGE:
#
# PrepareData.sh FWD.fastq.gz REV.fastq.gz Barcodes.txt 4
#
# <-- runs the script using 4 threads
#
#
# This is script 1 of the Illumina metabarcoding pipeline that cleans up the raw data,
# creates contigs of the paired MiSeq reads, and splits the file into the seaparate samples
# based on the tags used in library preparation
#
# The input are raw, paired-end Illumina fastq files (gzip compressed or uncompressed),
# and a file containg the barcodes used for tagging individual samples
#
# The file format for the latter is:
#
# Sample_1  AGACGC
# Sample_2  AGTGTA
# Sample_3  ACTAGC
#
# The script requires 4 arguments:
# 1) the file containing the first set of reads (forward)
# 2) the file containing the second set of reads (reverse)
# 3) the file containing the tags and sample names (see above)
# 4) the number of threads to use (current


# Forward and Reverse read files in fastq format
FWD=$1
REV=$2
# The file containing the tags (barcodes to split the files into samples.
TAGS=$3
# The number of threads (CPUs) to use; default = 1
THREADS=$4
if [ ! -z "$THREADS" ]
then
    THREADS=1
fi

# Output Files
FWD_TRIM=${FWD%.*}_trim.fastq
REV_TRIM=${REV%.*}_trim.fastq

# The Smithsonian Hydra cluster uses a module environment
# Here, the script loads all necessary modules to process
# the raw Illumina files

module load bioinformatics/mothur/1.35.1
module load bioinformatics/biopython/1.66
module load bioinformatics/fastxtoolkit/0.0.13
module load bioinformatics/cutadapt/1.9.1
module load bioinformatics/trimmomatic/0.33
module load bioinformatics/anaconda/2.2.0
source activate screed

# STEP 1: trimmomatic cleans the raw data

java -jar /share/apps/bioinformatics/trimmomatic/0.33/trimmomatic-0.33.jar SE -threads $THREADS -phred33 $FWD $FWD_TRIM MAXINFO:200:0.5
java -jar /share/apps/bioinformatics/trimmomatic/0.33/trimmomatic-0.33.jar SE -threads $THREADS -phred33 $REV $REV_TRIM MAXINFO:200:0.5

# STEP 2: test if fwd and rev trimmed files contain the same number of sequences; if not
# run the python script below to pair reads again

FWD_SIZE=`wc -l $FWD_TRIM | awk '{ print $1 }'`
REV_SIZE=`wc -l $REV_TRIM | awk '{ print $1 }'`

if [ "$FWD_SIZE" -ne "$REV_SIZE" ]
then

echo "Trimmed Fastq files are of unequal size!"
echo "This will be fixed now and the output written to $FWD_TRIM and $REV_TRIM..."

python << EOF

import subprocess, screed, sys

R1_IN = subprocess.check_output(["printf","$FWD_TRIM"])
R2_IN = subprocess.check_output(["printf","$REV_TRIM"])

screed.read_fastq_sequences(R1_IN)
screed.read_fastq_sequences(R2_IN)

DB_R1 = screed.ScreedDB(R1_IN+'_screed')
DB_R2 = screed.ScreedDB(R2_IN+'_screed')

with open(R1_IN,'w') as R1_OUT:
    with open(R2_IN,'w') as R2_OUT:
        for record, thing in DB_R1.iteritems():
            try:
                match = DB_R2[thing['name'].replace(" 1:"," 2:")]
            except KeyError:
                continue
            R1_OUT.write('@%s %s\n%s\n+\n%s\n' % (thing['name'],thing['annotations'],thing['sequence'],thing['quality']))      
            R2_OUT.write('@%s %s\n%s\n+\n%s\n' % (match['name'],match['annotations'],match['sequence'],match['quality']))
EOF

rm -v *screed

fi

# STEP 3: Make contigs with the cleaned up data using Mothur; contigs are trimmed again

mothur "#make.contigs(ffastq=$FWD_TRIM, \
    rfastq=$REV_TRIM, \
    processors=$THREADS); \
    trim.seqs(fasta=${FWD_TRIM%.*}.trim.contigs.fasta, \
    checkorient=t, \
    maxambig=0, \
    maxhomop=8, \
    minlength=300, \
    maxlength=450, \
    bdiffs=1, \
    pdiffs=2, \
    processors=$THREADS)"

# STEP 4: Split file into samples specified in the barcodes file (option 3) with fastx_barcode_splitter

cat ${FWD_TRIM%.*}.trim.contigs.trim.fasta | fastx_barcode_splitter.pl --bcfile $TAGS --bol --prefix OUT_ --suffix .fasta

# STEP 5: Remove adapters (ie, COI primers plus barcodes) from 5' and 3' ends of contigs

# For some reason cutadapt does a better job cutting out adapters when called multiple times...
for SAMPLE in OUT_*fasta
do
    echo $SAMPLE
    cutadapt -e 0.1 -g GGNACNGGNTGAACNGTNTANCCNCC --match-read-wildcards $SAMPLE | \
    cutadapt -e 0.1 -g TANACNTCNGGNTGNCCNAANAANCA --match-read-wildcards - | \
    cutadapt -e 0.1 -a GGNGGNTANACNGTTCANCCNGTNCC --match-read-wildcards - | \
    cutadapt -e 0.1 -a TGNTTNTTNGGNCANCCNGANGTNTA --match-read-wildcards - > ${SAMPLE/OUT_/}

done && rm -v OUT_* && rm -v *logfile && rm -v *contigs*

# STEP 6: To facilitate downstream analyses and mapping of sequences to samples the
# sequences are renamed by appending the sample name to the beginning of the seqeuence
# names - Python is used for this again

for SAMPLE in *fasta
do

python << EOF

import screed, sys, subprocess

FastaFile = subprocess.check_output(["printf","$SAMPLE"])
OutFile = 'temp'

with open(OutFile, 'w') as Out:
    for n, record in enumerate(screed.open(FastaFile)):
        SampleName = FastaFile.split('.')[0]
        Out.write('>%s-%s\n%s\n' % (SampleName, record['name'], record['sequence']))

EOF

mv temp $SAMPLE

done

# STEP 7: Lastly, Mothur is used to create alignments of individual sample files against
# a reference database of COI sequences, sequences in the wrong orientation are reverse
# complemented, sequences are then dereplicated, and chimeric sequences identifed using
# Uchime

for FASTA in *fasta
do
    if [ "unmatched.fasta" != "$FASTA" ]
    then
        echo $FASTA
        mothur "#align.seqs(candidate=$FASTA, \
            template=BIOCODETEMPLATE, \
            flip=t, \
            processors=$THREADS); \
            summary.seqs(fasta=${FASTA/fasta/align}); \
            unique.seqs(fasta=${FASTA/fasta/align}); \
            chimera.uchime(fasta=${FASTA/fasta/unique.align}, \
            name=${FASTA/fasta/names}); \
            remove.seqs(fasta=${FASTA/fasta/unique.align}, \
            accnos=${FASTA/fasta/unique.uchime.accnos})"
    fi
done
