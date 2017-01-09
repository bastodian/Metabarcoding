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

if *git* is available...

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

#### Running the script:


