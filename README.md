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

##Worfkflow Overview
<img width="328" height="828" alt="Screenshot 2026-08-06 at 17 06 05" src="https://github.com/user-attachments/assets/e1098c2b-b3f7-4dc7-8710-b3983b25a418" />

#Requirements
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

