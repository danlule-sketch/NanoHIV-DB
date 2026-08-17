# NanoHIV-DB:Nanopore HIV Drug Resistance Analysis Pipeline.

## Introduction
NanoHIV-DB is a Nextflow pipeline for the analysis of HIV-1 drug resistance for Oxford Nanopore-generated sequences. The workflow accepts POD5 files and integrates several quality filtering and polishing steps, and queries the Stanford HIVdb to generate drug resistance profiles.

## Overview
NanoHIV-DR is a Nextflow-based pipeline designed to analyse Oxford Nanopore HIV sequencing data. The workflow carries out the following key steps:
1.	Nanopore basecalling using Dorado
2.	Barcode demultiplexing using Dorado
3.	Read quality filtering using NanoQ
4.	Consensus polishing using Medaka
5.	Read mapping back to the polished HIV genome using Minimap2
6.	HIV drug resistance analysis using SierraPy, a standalone installation
7.	Codon frequency analysis using SierraPy built-in algorithm 
8.	Automated HIV subtype query, phylogenetic analysis, and reporting 
9.	The pipeline is containerised using Docker to ensure reproducibility.

## Worfkflow Overview
<img width="502" height="691" alt="Screenshot 2026-08-12 at 20 36 16" src="https://github.com/user-attachments/assets/a5a2d61f-e6e4-4eb6-9727-bd359e7463db" />

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

The file structure is demonstrated below:

<img width="354" height="354" alt="Screenshot 2026-08-17 at 12 12 51" src="https://github.com/user-attachments/assets/ee7ab4a0-6aeb-401e-b0b0-c16d080e1ae7" />

The architecture of the "main.nf" file that connects the workflow is shown below:

<img width="326" height="255" alt="Screenshot 2026-08-17 at 12 15 39" src="https://github.com/user-attachments/assets/97cef75b-2837-42aa-99a1-3b7a23ebc715" />

The Dockerfile download will contain a file structure as shown below:

<img width="186" height="208" alt="Screenshot 2026-08-17 at 12 22 05" src="https://github.com/user-attachments/assets/e8cd994a-b99c-437b-af1c-ac1a45510057" />

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

If you use NanoHIV-DR in research, please cite: Daniel Lule Bugembe, Deogratius Ssemwanga, Pontiano Kaleebu & Damien C. Tully. NanoHIV-DR: An end-to-end workflow for the detection of HIV-1 drug resistance of pol-gene Oxford Nanopore sequences. (Draft paper 2026)

# Contact

For questions, bug reports, feature requests, or other issues related to NanoHIV-DR, please use the [GitHub Issues](https://github.com/danlule-sketch/NanoHIV-DB/issues/new/choose) page. For issues, feature requests or bug reports:

Before opening a new issue, please check the existing issues to see whether your question or problem has already been reported.

- 🐛 [Report a bug](https://github.com/danlule-sketch/NanoHIV-DB/issues/new?template=bug_report.md)
- 💡 [Request a feature or data improvement](https://github.com/danlule-sketch/NanoHIV-DB/issues/new?template=feature_request.md)
- 🔎 [View existing issues](https://github.com/danlule-sketch/NanoHIV-DB/issues)




