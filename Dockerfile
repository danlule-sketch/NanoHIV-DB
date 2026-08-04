FROM mambaorg/micromamba:latest

LABEL maintainer="NanoHIV-DR"
LABEL description="CPU-only Docker environment for NanoHIV-DR Nextflow pipeline"


USER root

# --------------------------------------------------
# Basic system utilities
# --------------------------------------------------

RUN apt-get update && apt-get install -y \
    wget \
    curl \
    git \
    tar \
    gzip \
    bzip2 \
    xz-utils \
    && rm -rf /var/lib/apt/lists/*


# --------------------------------------------------
# Bioinformatics software
# --------------------------------------------------

RUN micromamba install -y -n base \
    -c conda-forge \
    -c bioconda \
    minimap2 \
    samtools \
    seqtk \
    canu \
    medaka \
    nanoq \
    && micromamba clean --all --yes


# --------------------------------------------------
# Dorado (Linux x64)
# Copied from local project folder
# --------------------------------------------------

COPY containers/dorado-linux-x64 /opt/dorado

ENV PATH="/opt/dorado/bin:${PATH}"


# --------------------------------------------------
# Default working directory
# --------------------------------------------------

WORKDIR /data