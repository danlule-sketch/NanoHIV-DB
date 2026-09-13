# ============================================================
# NanoHIV-DR pipeline container
# ============================================================
#
# Target architecture:
#     linux/amd64
#
# This image contains:
#
#   - Dorado
#   - minimap2
#   - samtools
#   - seqtk
#   - NanoQ
#   - medaka
#   - mafft
#   - RAxML
#   - bcftools
#   - SanitizeMe
#   - Python
#   - NanoHIV-DR reporting scripts
#
# CodFreq is NOT installed here because the Nextflow
# CODFREQ module uses:
#
#     hivdb/codfreq:latest
#
# as its own container.
#
# ============================================================


FROM --platform=linux/amd64 mambaorg/micromamba:latest


# ============================================================
# Base configuration
# ============================================================

USER root

ENV DEBIAN_FRONTEND=noninteractive

# Explicit micromamba root prefix
ENV MAMBA_ROOT_PREFIX=/opt/conda

# Main executable paths
ENV PATH="/opt/dorado/bin:/opt/REPORT:/opt/REPORT/bin:/opt/conda/envs/SanitizeMe/bin:${PATH}"


# ============================================================
# System packages
# ============================================================

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        bash \
        wget \
        curl \
        git \
        python3 \
        python3-pip \
        unzip \
        tar \
        gzip \
        ca-certificates \
        coreutils \
        procps \
        grep \
        sed \
        gawk \
        findutils \
    && \
    rm -rf /var/lib/apt/lists/*


# ============================================================
# Bioinformatics software
# ============================================================
#
# These tools are installed into the base micromamba
# environment and are therefore available on PATH.
#
# ============================================================

RUN micromamba install -y \
        -n base \
        -c conda-forge \
        -c bioconda \
        minimap2 \
        samtools \
        seqtk \
        nanoq \
        medaka \
        mafft \
        raxml \
        bcftools \
    && \
    micromamba clean --all --yes


# ============================================================
# SanitizeMe
# ============================================================
#
# Installed into a dedicated environment.
#
# The environment's bin directory is added to PATH above:
#
#     /opt/conda/envs/SanitizeMe/bin
#
# Therefore the Nextflow module can simply call:
#
#     sanitizeme
#
# ============================================================

RUN micromamba create -y \
        -n SanitizeMe \
        -c conda-forge \
        -c bioconda \
        sanitizeme \
    && \
    micromamba clean --all --yes


# ============================================================
# Dorado
# ============================================================
#
# The repository must contain:
#
#     containers/dorado-linux-x64/
#
# containing:
#
#     containers/dorado-linux-x64/bin/dorado
#
# ============================================================

COPY containers/dorado-linux-x64 /opt/dorado


RUN chmod +x /opt/dorado/bin/dorado


# ============================================================
# NanoHIV-DR reporting software
# ============================================================
#
# The repository must contain:
#
#     REPORT/
#
# with at least:
#
#     REPORT/preprocessing.sh
#
# and any supporting scripts under:
#
#     REPORT/bin/
#
# ============================================================

COPY REPORT /opt/REPORT


# ============================================================
# Make reporting scripts executable
# ============================================================

RUN chmod +x /opt/REPORT/preprocessing.sh && \
    if [ -d /opt/REPORT/bin ]; then \
        chmod +x /opt/REPORT/bin/*.py; \
    fi


# ============================================================
# Verify installation
# ============================================================

RUN echo "============================================================" && \
    echo " Checking NanoHIV-DR container" && \
    echo "============================================================" && \
    echo "" && \
    echo "Python:" && \
    python3 --version && \
    echo "" && \
    echo "Dorado:" && \
    dorado --version && \
    echo "" && \
    echo "Minimap2:" && \
    minimap2 --version && \
    echo "" && \
    echo "Samtools:" && \
    samtools --version | head -n 1 && \
    echo "" && \
    echo "Seqtk:" && \
    seqtk 2>&1 | head -n 1 || true && \
    echo "" && \
    echo "NanoQ:" && \
    nanoq --version || true && \
    echo "" && \
    echo "MAFFT:" && \
    mafft --version | head -n 1 && \
    echo "" && \
    echo "BCFtools:" && \
    bcftools --version | head -n 1 && \
    echo "" && \
    echo "SanitizeMe:" && \
    command -v sanitizeme && \
    echo "" && \
    echo "REPORT:" && \
    test -x /opt/REPORT/preprocessing.sh && \
    echo "/opt/REPORT/preprocessing.sh OK" && \
    echo "" && \
    echo "============================================================" && \
    echo " NanoHIV-DR container OK" && \
    echo "============================================================"


# ============================================================
# Working directory
# ============================================================

WORKDIR /data


# ============================================================
# Default command
# ============================================================

CMD ["bash"]
