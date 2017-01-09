# Metabarcoding analysis pipeline

This pipeline takes multiplexed and barcoded fastq sequence files and prcoesses
them for further analysis of barcoded metacommunities.

Generally, the pipeline is modular consisting of multiple scripts that perform
several operations without further user input. Every step is split into a shell
script (.sh extension) that performs the data processing and a submission script
(.job extension) that sets the data up for analysis, loads the appropriate software
(modules), and submits jobs to the queue on the Smithsonian Hydra Cluster.

The different scripts combine related tasks and were also optimized to make use of
the opportunities to run tasks in parallel on the cluster. Here, tasks were grouped 
into a single script that can be parallelised in similar ways. This should remove
bottlenecks in data processing.

**Downloading the pipeline to Hydra:**

```bash
curl -L0 https://github.com/bastodian/Metabarcoding/archive/master.zip > MetabarcodingPipe.zip

unzip MetabarcodingPipe.zip
```

All scripts and files will be placed into the directory Metabarcoding-master and can be run 
from there or moved somewhere else.

```bash
# Navigate into the directory...

cd Metabarcoding-master

# Make all scripts executable...

chmod u+x *.job && chmod u+x *.sh
```

**On your local machine:**

either use *curl* (see above) or *git* if available...

```bash
git clone https://github.com/bastodian/Metabarcoding/archive/master.zip
```

## Script 1: Prep Data

Performs basic QC on the raw data, assembles the paired short reads, and splits the 
resulting assembled reads into separate files based on their barcodes. Finally,
barcodes and adapter sequences are stripped from the assembled contigs.

#### Short overview of all steps:

1. Trimmomatic removes low quality bases
2. A check is performed to ensure that forward and reverse fastq files contain the same
    number of sequences after trimming; if not the pairing of forward and reverse reads
    is re-estalished and orphans (only forward or reverse sequence present) are discarded
3. Mothur is used to assemble forward and reverse reads; only contigs of lengths 300-450bp
    are retained
4. FastX barcode splitter is used to sort contigs into their respective bins using the barcodes
    supplied in a flat text file
5. Adapters and barcordes are stripped from teh sorted contigs using Cutadapt
6. To facilitate downstream analyses the sample name (taken from the barcode textfile) is
    appended to the beginning of the fasta header in each contigs fasta file

#### Running the 1st part of the pipeline:

The submission script 1_PrepData.sh handles the submission of the data to Hydra's queue and
call 1_PrepData.job.

The data needs to be organized in the following way. Fastq files are supplied as gzipped (gz)
fastq files. Forward sequences are contained in a file that contains *_R1_* in its name while
reverse sequences are in a file containing *_R2_* in its name. *IMPORTANT* - every matching 
pair of forward and reverse sequences are together in a directory (see below).

```bash
Index12/R1-Index12_S7_L001_R1_001.fastq.gz
Index12/R1-Index12_S7_L001_R2_001.fastq.gz
Index15/R1-Index15_S8_L001_R1_001.fastq.gz
Index15/R1-Index15_S8_L001_R2_001.fastq.gz
Index16/R1-Index16_S9_L001_R1_001.fastq.gz
Index16/R1-Index16_S9_L001_R2_001.fastq.gz
Index19/R1-Index19_S6_L001_R1_001.fastq.gz
Index19/R1-Index19_S6_L001_R2_001.fastq.gz
```

In addition to the sequence files every directory contains a flat text file with that lists barcodes
and sample names.

```bash
./Index12/R1I12.txt
./Index15/R1I15.txt
./Index16/R1I16.txt
./Index19/R1I19.txt
```

Example barcodes text file:

```bash
PNG_7_100       AGACGC
PNG_1_Sess      AGTGTA
PNG_19_500      ACTAGC
PNG_21_SES      ACAGTC
PNG_27_100      ATCGAC
```

**Running step1** after you have set up directories and barcode text files:

Copy both 1_PrepData.sh and 1_PrepData.job to the directory containing all your directories that 
hold the barcode text files and fastq files. Then execute the script and specify how many threads you
want to use for each job (generally, not much speed improvement is to be expected beyond 4 threads)

**NOTE** - a separate job will be submitted for each pair of fastq files, thus parallelizing the 
data processing in this way already.

```bash
# Submit jobs that request 4 threads each

./1_PrepData.job 4
```

**Output:**

To be written...


