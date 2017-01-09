# Metabarcoding analysis pipeline

This pipeline takes multiplexed and barcoded fastq sequence files and prcoesses
them for further analysis of barcoded metacommunities.

Generally, the pipeline is modular consisting of multiple scripts that perform
several operations without further user input. Every step is split into a shell
script (.job extension) that performs the data processing and a submission script
(.sh extension) that sets the data up for analysis, loads the appropriate software
(modules), and submits jobs to the queue on the Smithsonian Hydra Cluster.

The different scripts combine related tasks and were optimized to make use of
the opportunities to run tasks in parallel on the cluster. Here, tasks were grouped 
into a single script that can be parallelized in similar ways. This should remove
bottlenecks in data processing.

**Downloading the pipeline to Hydra:**

```bash
curl -L0 https://github.com/bastodian/Metabarcoding/archive/master.zip > MetabarcodingPipe.zip

unzip MetabarcodingPipe.zip
```

All scripts and files will be placed into the directory Metabarcoding-master and should be moved/
copied into the directory containing your data.

*This shouldbe changed in the future to allow running scripts from anywhere, by pointing them 
to the data directory.*

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

## Step 1: Prepare Data

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

The submission script [1_PrepData.sh](https://github.com/bastodian/Metabarcoding/blob/master/1_PrepData.sh) handles the submission of the data to Hydra's queue and
call [1_PrepData.job](https://github.com/bastodian/Metabarcoding/blob/master/1_PrepData.job).

The data needs to be organized in the following way. Fastq files are supplied as gzipped (gz)
fastq files. Forward sequences are contained in a file that contains *_R1_* in its name while
reverse sequences are in a file containing *_R2_* in its name. **IMPORTANT** - every matching 
pair of forward and reverse sequences are together in a directory (see below).

```bash
MYDATA/Index12/R1-Index12_S7_L001_R1_001.fastq.gz
MYDATA/Index12/R1-Index12_S7_L001_R2_001.fastq.gz
MYDATA/Index15/R1-Index15_S8_L001_R1_001.fastq.gz
MYDATA/Index15/R1-Index15_S8_L001_R2_001.fastq.gz
MYDATA/Index16/R1-Index16_S9_L001_R1_001.fastq.gz
MYDATA/Index16/R1-Index16_S9_L001_R2_001.fastq.gz
```

In addition to the sequence files every directory contains a flat text file with that lists barcodes
and sample names.

```bash
MYDATA/Index12/R1I12.txt
MYDATA/Index15/R1I15.txt
MYDATA/Index16/R1I16.txt
```

Example barcodes text file:

```bash
PNG_7_100       AGACGC
PNG_1_Sess      AGTGTA
PNG_19_500      ACTAGC
PNG_21_SES      ACAGTC
PNG_27_100      ATCGAC
```

**Running Step 1** after you have set up directories and barcode text files:

Copy both 1_PrepData.sh and 1_PrepData.job to the directory containing all your directories that 
hold the barcode text files and fastq files. Then execute the script and specify how many threads you
want to use for each job (generally, not much speed improvement is to be expected beyond 4 threads)

**NOTE** - a separate job will be submitted for each pair of fastq files, thus parallelizing the 
data processing in this way already.

```bash
# Submit jobs that request 4 threads each

cd MYDATA

./1_PrepData.job 4
```

**Output:**

To be written...

## Step 2: Preliminary Alignments

In step 2, Mothur is used to perform a preliminary alignment against a reference database following
Mothur's SOPs. The 2 scripts for this are the submission script [2_PrelimAlign.sh](https://github.com/bastodian/Metabarcoding/blob/master/2_PrelimAlign.sh) and
the job script [2_PrelimAlign.job](https://github.com/bastodian/Metabarcoding/blob/master/2_PrelimAlign.job) that runs the job.

1. Sequences are aligned against a refefernce alignment
2. Sequences in the wrong orientation are flipped (reverse complemented)
3. Duplicate are sequences removed
4. Chimeric sequences flagged and removed.

Following Step 1 of the pipeline above fasta files containg the assembled sequences will have been 
generated. Here, every directory that contained a gzipped fastq files of raw Illumina data now contains
as many fasta files as there were barcodes used to distinguish among samples. Inthe example below,
every directory contains 5 sample files with contigs (named accoriding to the naming scheme provided in
barcodes text file (see Step 1 above). In addition, contigs that couldn't be confidently placed with any
of the samples due to ambiguous or incomplete barcodes are contained in the *unmatched.fasta* file - these
are ignored in downstream analyses.

```bash
MYDATA/Index12/PNG_19_500.fasta
MYDATA/Index12/PNG_1_Sess.fasta
MYDATA/Index12/PNG_21_SES.fasta
MYDATA/Index12/PNG_27_100.fasta
MYDATA/Index12/PNG_7_100.fasta
MYDATA/Index12/unmatched.fasta
MYDATA/Index15/PNG_22_SES.fasta
MYDATA/Index15/PNG_27_500.fasta
MYDATA/Index15/PNG_28_500.fasta
MYDATA/Index15/PNG_2_Sess.fasta
MYDATA/Index15/PNG_8_100.fasta
MYDATA/Index15/unmatched.fasta
MYDATA/Index16/PNG_19_100.fasta
MYDATA/Index16/PNG_23_500.fasta
MYDATA/Index16/PNG_23_SES.fasta
MYDATA/Index16/PNG_3_Sess.fasta
MYDATA/Index16/PNG_9_100.fasta
MYDATA/Index16/unmatched.fasta
```

**Running Step 2:**

The scripts for this step can be run from anywhere and just need to be pointed to the reference alignment and 
the directory containing the data to be processed. A separate job will be submitted for each individual alignment, 
effectively parallelizing the alignment generation in this fashion.

```bash
# Move to where both 2_PrelimAlign.job and 2_PrelimAlign.sh are located and execute the script as follows,
# pointing the submission script to the reference alignment (the BIOCODETEMPLATE provides a good reference)

./2_PrelimAlign.sh MYDATA TemplateAlignmentFasta
```

**Output:**

To be written...

## Step 3: Align Sequences using the codon model of MACSE

While Mothur produces decent alignments it does not check whether or not sequences possess an open reading frame
that suggests the sequence to be coding rather than a pseudogene, sequencing artefact... Here, MACSE provides 
a good way to prune sequenes without good open reading frames (eg, stop codons in the sequence). In addition,
the alignment is refined using the more conserved amino acid translation into account.

MACSE does have limitations in the number of sequences it can process at a time. Thus, it is necessary to split the
alignment into multiple sub-alignments containing 5,000, 10,000, or possibly more sequences. 5,000 or 10,000 seem to 
be a good numbers, leading to reasonable run times - the user will be prompted to provide that number once when executing
this step of the pipeline.

To speed up processing, MACSE is also run using a reference to align sequences against rather than using its *de novo* 
alignment method.

In order to run multiple sub-alignments, the Mothur alignment generated in Step 2 (see above) is split into multiple files
and alignments are run separately on these files, generating multiple separate alignments.

[3_MacseAlign.sh](https://github.com/bastodian/Metabarcoding/blob/master/3_MacseAlign.sh) automates all of the steps outlined
above and prepares the reduced-size fasta files and directory structure to align these fasta files with MACSE. After the prep
work is done the submission script [3_MacseAlign.job](https://github.com/bastodian/Metabarcoding/blob/master/3_MacseAlign.job) is
called, subitting an array job for each sample that needs to be aligned.

In summary, the alignment task is split into several sub-tasks per sample. These sub-tasks are submitted to the queue on Hydra as
array jobs, creating a separate array job for each seaprate sample to process the data as effeciently as possible. At present,
the inverterate mitochondrial code is hardcoded into the script (*-gc_def 5*).

#### Running Step 3:

Both [3_MacseAlign.job](https://github.com/bastodian/Metabarcoding/blob/master/3_MacseAlign.job) and [3_MacseAlign.sh](https://github.com/bastodian/Metabarcoding/blob/master/3_MacseAlign.sh)
need to be copied into the data directory containing the sample directories - in the example used troughout here that would be
*MYDATA*.

```bash
# Executing 3_Macse_align.sh will prompt the user for a number of sequences into which each fasta file should be split.
# After that the script creates all files and directories necessary and submits the MACSE alignment jobs to the queue 
# automatially. The input are the Mothur alignments with the extension .unique.pick.align.

MYDATA/3_MacseAlign.sh
```

**Output:**

To be written...

## TO DO

Step 3 creates a number of separate MACSE alignments. These may be off-set from each other since the sequences were aligned 
separately. Here, Mothur can be used to realign these sub-alignments to each other using one of the sub-alignments as a reference.
This is written and has been tested but needs to be cleaned up to be included in the repository here.

Following the combination of MACSE alignments, sequences need to be clustered to facilitate comparisons of OTUs across samples. Here,
CROP provides a good but relatively slow approach. Again, this has been tested and used on some f the data but needs tobe cleaned up
to fully automate and include it here.

For quick and dirty preliminary analyses vsearch has been used on a subset of the data, producing resaonable results. This also needs
tobe cleaned up to automate it.

```bash
vsearch --threads THREADS --cluster_fast FASTA_FILE
```
