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
Input:
 ├── Nanopore POD5 files
 └── Patient metadata table (TSV)
        |
        v
Dorado basecalling
        |
        v
Demultiplexing
        |
        v
Human read removal
        |
        v
NanoQ quality filtering
        |
        v
Canu assembly
        |
        v
Medaka polishing
        |
        v
Minimap2 read mapping
        |
        +----------------+
        |                |
        v                v
 CodFreq analysis     HIVdb resistance scoring
        |
        v
Automated report generation
        |
        v
Subtype query
MAFFT alignment
RAxML phylogeny
Phylogenetic visualisation
DOCX report

#Requirements
The following software must be installed:
## Docker
https://www.docker.com/products/docker-desktop/

Check installation
'''docker --version'''
