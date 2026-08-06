# NanoHIV-DB:Nanopore HIV Drug Resistance Analysis Pipeline.

## Introduction
NanoHIV-DB is a Nextflow pipeline for the analysis of HIV-1 drug resistance for Oxford Nanopore-generated sequences. The workflow accepts POD5 files and integrates several quality filtering and polishing steps, and queries the Stanford HIVdb to generate drug resistance profiles.

## Overview
NanoHIV-DR is a Nextflow-based pipeline designed to analyse Oxford Nanopore HIV sequencing data. The workflow carries out the following key steps:
1.	Nanopore basecalling using Dorado
2.	Barcode demultiplexing using Dorado
3.	Removal of human host reads using RemoveHost
4.	Read quality filtering using NanoQ
5.	De novo HIV genome assembly using CANU
6.	Consensus polishing using Medaka
7.	Read mapping back to the polished HIV genome using Minimap2
8.	HIV drug resistance analysis using SierraPy, a standalone installation
9.	Codon frequency analysis using SierraPy built-in algorithm 
10.	Automated HIV subtype query, phylogenetic analysis and reporting
11.	
The pipeline is containerised using Docker to ensure reproducibility.

## Worfkflow Overview
<img width="328" height="828" alt="Screenshot 2026-08-06 at 17 06 05" src="https://github.com/user-attachments/assets/e1098c2b-b3f7-4dc7-8710-b3983b25a418" />

# Requirements
The following software must be installed:
## 1. Docker
https://www.docker.com/products/docker-desktop/

Check installation
'docker --version'

## 2. Nextflow
### Install Nextflow:
'curl -s https://get.nextflow.io | bash'

### Move Nextflow into your PATH:
'sudo mv nextflow /usr/local/bin/'

# Download NanoHIV-DR

### Clone the repository:
'git clone https://github.com/YOUR_USERNAME/NanoHIV-DR.git'

### Move into the pipeline directory:

'cd NanoHIV-DR'

<img width="306" height="729" alt="Screenshot 2026-08-06 at 17 26 18" src="https://github.com/user-attachments/assets/5642400c-4fda-46ce-8140-ade10dcaccbc" />

### Note: 
The images logoUVRI.png and logoCVR can be replaced with your institutional images to customise your reporting.

# Build the Docker image

### From the NanoHIV-DR directory:

'''
docker buildx build \
--platform linux/amd64 \
-t nanohiv-dr-cpu:latest \
--load .
'''
### Confirm the image exists:

'docker images | grep nanohiv'

### Expected output:

'nanohiv-dr-cpu    latest'

## 1. Nanopore POD5 data

data/pod5/

## 2. Patient metadata table

The user must provide a TSV file containing patient/sample information.

### Example:

my_patient_table.tsv

### Example format:

The metadata file is supplied every time the pipeline is run.

# Running NanoHIV-DR

### Basic Command

'''
nextflow run main.nf \
--pod5 data/pod5 \
--metadata my_patient_table.tsv
'''

# Resume interrupted runs

Nextflow automatically caches completed steps.

If a run stops:

'''
nextflow run main.nf -resume \
--pod5 data/pod5 \
--metadata metadata.tsv
'''

Only incomplete steps will restart.

# CPU configuration

### The default configuration uses:

threads = 8

### Change this in:

nextflow.config

### or at runtime:

'''
nextflow run main.nf \
--threads 16 \
--pod5 data/pod5 \
--metadata metadata.tsv
'''

# Troubleshooting

## Docker platform warning on Apple Silicon

If using an ARM64 Mac (M1/M2/M3/M4):
You may see: requested image platform linux/amd64 does not match host platform

This is expected because the container uses the x86_64 Dorado binary.

The pipeline runs using Docker emulation.

# Citation

If you use NanoHIV-DR in research, please cite:

# Contact
For issues, feature requests or bug reports:






