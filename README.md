<img width="484" height="699" alt="Screenshot 2026-09-13 at 13 37 41" src="https://github.com/user-attachments/assets/d2965799-0baf-4cef-a0b4-31ec2ca71609" />
# NanoHIV-DB: Nanopore HIV Drug Resistance Analysis Pipeline.

## Introduction
NanoHIV-DB is a Nextflow pipeline for the analysis of HIV-1 drug resistance for Oxford Nanopore-generated sequences. The workflow accepts POD5 files and integrates several quality filtering and polishing steps, and queries the Stanford HIVdb to generate drug resistance profiles.

## Overview
NanoHIV-DR is a Nextflow-based pipeline designed to analyse Oxford Nanopore HIV sequencing data. The workflow carries out the following key steps:
1.	Nanopore basecalling using Dorado
2.	Barcode demultiplexing using Dorado
3.	Remove host DNA using Removehost. This requires downloading the human reference genome either via https://github.com/jiangweiyao/SanitizeMe or directly through the Linux command wget ftp://ftp-trace.ncbi.nih.gov/1000genomes/ftp/technical/reference/human_g1k_v37.fasta.gz
4.	Read quality filtering using NanoQ
5.	Consensus polishing using Medaka
6.	Read mapping back to the polished HIV genome using Minimap2
7.	HIV drug resistance analysis using SierraPy, a standalone installation
8.	Codon frequency analysis using SierraPy built-in algorithm 
9.	Automated HIV subtype query, phylogenetic analysis, and reporting 
10.	The pipeline is containerised using Docker to ensure reproducibility.

## Workflow Overview

<img width="385" height="539" alt="Screenshot 2026-09-10 at 15 00 38" src="https://github.com/user-attachments/assets/47d769ec-96b1-46c6-9868-c6a12017522f" />

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

<img width="347" height="639" alt="Screenshot 2026-09-10 at 15 26 46" src="https://github.com/user-attachments/assets/2d46c173-cfec-4f6c-bbfd-a298f2ade4ff" /> <br><br> 

The architecture of the "main.nf" file that connects the workflow is shown below:
<img width="428" height="781" alt="Screenshot 2026-09-10 at 15 54 46" src="https://github.com/user-attachments/assets/eb1b1f08-ccc4-4003-9d99-9a9bbac26281" /> <br> <img width="426" height="586" alt="Screenshot 2026-09-10 at 15 55 48" src="https://github.com/user-attachments/assets/56294191-1883-42c8-a5f3-a2c16539a037" />


### Note: 
The images logoUVRI.png and logoCVR can be replaced with your institutional images to customise your reporting.

# Build the Docker image

### From the NanoHIV-DR directory:


```
docker buildx build \
  --platform linux/amd64 \
  -t nanohiv-dr-cpu:latest \
  --load .
```

You can verify the image platform:

```
docker image inspect nanohiv-dr-cpu:latest \
  --format '{{.Os}}/{{.Architecture}}'
```

### Confirm the image exists:

```
'docker images | grep nanohiv'
```

### Expected output:

```
'nanohiv-dr-cpu    latest'
```

## 1. Nanopore POD5 data

```
data/pod5/
```

## 2. Patient metadata table

The user must provide a TSV file containing patient/sample information.

### Example:

```
my_patient_table.tsv
```

### Example format:

The metadata file is supplied every time the pipeline is run.

# Running NanoHIV-DR

### Basic Command

NanoHIV-DR is run in two stages. Stage 1 processes the raw Oxford Nanopore POD5 data through basecalling, demultiplexing, read filtering, alignment, polishing, and consensus generation. To run Stage 1, provide the directory containing the POD5 files:

```
nextflow run main.nf \
    --stage consensus \
    --pod5 data/pod5 \
    --outdir results
```
When Stage 1 completes, the pipeline creates a consensus FASTA and a metadata_template.tsv file in results/consensus/. Complete the metadata template with the required sample information without changing the sample_id values, and save the completed file as metadata.tsv.

Stage 2 uses the consensus sequences and completed metadata to validate sample identifiers and generate the clinical report:

```
nextflow run main.nf \
    --stage report \
    --consensus results/consensus/consensus.fasta \
    --metadata metadata.tsv \
    --outdir results
```

### Note:
The pipeline will stop during Stage 2 if the sample identifiers in the metadata do not exactly match those in the consensus FASTA.

The metadata table, "metadata.tsv" should be formatted so that the second column, named "Our/Alternative ID" has exactly the same identifiers with the fasta sequence headers, as the JSON output is matched with this to generate the clinical reports. The format of the data table is shown below. 

<img width="1764" height="276" alt="Screenshot 2026-08-17 at 13 49 14" src="https://github.com/user-attachments/assets/024096f0-10c2-43b6-a5b2-0e3e171c8068" />


### CAUTION!

Care should be taken to maintain confidentiality, as clinical reports may contain multiple pieces of information that, when combined, could potentially identify an individual.


# Resume interrupted runs

Nextflow automatically caches completed processes. If a run is interrupted, use the -resume option to continue the workflow without unnecessarily repeating processes that have already completed successfully.

For an interrupted Stage 1 run:

### For an interrupted Stage 1 run:

```
nextflow run main.nf \
    --stage consensus \
    --pod5 data/pod5 \
    --outdir results \
    -resume
```

### For an interrupted Stage 2 run:

```
nextflow run main.nf \
    --stage report \
    --consensus results/consensus/consensus.fasta \
    --metadata metadata.tsv \
    --outdir results \
    -resume
```

Nextflow will reuse cached results where possible and rerun only processes that need to be completed.

# CPU configuration

The pipeline defines a default of 8 threads:

``` threads = 8 ```

This value can be overridden at runtime with ``` --threads ```, for example:

```
nextflow run main.nf \
    --stage consensus \
    --pod5 data/pod5 \
    --outdir results \
    --threads 16
```

The actual CPU allocation for individual processes is controlled by the process configuration in nextflow.config and/or the individual pipeline modules. Therefore, changing --threads only affects processes that are configured to use the params.threads value.

### Note:
The placement of -resume isn't important; Nextflow recognises it as a command-line option. So this is also perfectly valid:

```
nextflow run main.nf -resume \
    --stage consensus \
    --pod5 data/pod5 \
    --outdir results
```

# Troubleshooting

## Docker platform warning on Apple Silicon

NanoHIV-DR currently uses an x86_64 (`linux/amd64`) Dorado binary. Therefore, the Docker image is built for the `linux/amd64` platform.

If you are running NanoHIV-DR on an Apple Silicon Mac (M1/M2/M3/M4), your host system uses the ARM64 architecture. Docker may therefore display a warning such as:

WARNING: The requested image's platform (linux/amd64) does not match the detected host platform (linux/arm64/v8)

# Acknowledgement

We appreciate the contribution of Samantha Campbell whose workflow available at https://github.com/centre-for-virus-research/UVRI-HIV-diagnostic-report, was used with minor modifications for implementing the clinical report generation section. The pipeline was developed through a collaboration with the Medical Research Council (MRC) Centre for Virus Research (CVR), Glasgow, to suit the needs of the Uganda Virus Research Institute(UVRI). 

# Citation

If you use NanoHIV-DR in research, please cite: Daniel Lule Bugembe, Deogratius Ssemwanga, Pontiano Kaleebu & Damien C. Tully. NanoHIV-DR: An end-to-end workflow for the detection of HIV-1 drug resistance of pol-gene Oxford Nanopore sequences. (Draft paper 2026)

# Contact

For questions, bug reports, feature requests, or other issues related to NanoHIV-DR, please use the [GitHub Issues](https://github.com/danlule-sketch/NanoHIV-DB/issues/new/choose) page. For issues, feature requests or bug reports:

Before opening a new issue, please check the existing issues to see whether your question or problem has already been reported.

- 🐛 [Report a bug](https://github.com/danlule-sketch/NanoHIV-DB/issues/new?template=bug_report.md)
- 💡 [Request a feature or data improvement](https://github.com/danlule-sketch/NanoHIV-DB/issues/new?template=feature_request.md)
- 🔎 [View existing issues](https://github.com/danlule-sketch/NanoHIV-DB/issues)




