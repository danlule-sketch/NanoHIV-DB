# ============================================================
# NanoHIV-DR pipeline container
# ============================================================
#
# Target architecture:
#   linux/amd64
#
# This image contains:
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
#   hivdb/codfreq:latest
#
# as its own container.
# ============================================================

FROM --platform=linux/amd64 mambaorg/micromamba:latest

# ============================================================
# Base configuration
# ============================================================

USER root

ENV DEBIAN_FRONTEND=noninteractive

# Micromamba root prefix
ENV MAMBA_ROOT_PREFIX=/opt/conda

# Main executable paths
#
# All Conda/micromamba software is installed into the
# "base" environment, so explicitly expose its bin directory.
ENV PATH="/opt/conda/bin:/opt/dorado/bin:/opt/REPORT:/opt/REPORT/bin:${PATH}"

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
    && rm -rf /var/lib/apt/lists/*

# ============================================================
# Bioinformatics software
# ============================================================
#
# Everything is installed into the micromamba "base"
# environment.
#
# Keeping these tools in one environment makes them directly
# available to Nextflow when the container is used.
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
    sanitizeme \
    && micromamba clean --all --yes

# ============================================================
# Dorado
# ============================================================
#
# The repository must contain:
#
#   containers/dorado-linux-x64/
#
# containing:
#
#   containers/dorado-linux-x64/bin/dorado
# ============================================================

COPY containers/dorado-linux-x64 /opt/dorado

RUN chmod +x /opt/dorado/bin/dorado

# ============================================================
# NanoHIV-DR reporting software
# ============================================================
#
# The repository must contain:
#
#   REPORT/
#
# with at least:
#
#   REPORT/preprocessing.sh
#
# and any supporting scripts under:
#
#   REPORT/bin/
# ============================================================

COPY REPORT /opt/REPORT

# ============================================================
# Make reporting scripts executable
# ============================================================

RUN chmod +x /opt/REPORT/preprocessing.sh && \
    if [ -d /opt/REPORT/bin ]; then \
        find /opt/REPORT/bin -type f -name "*.py" -exec chmod +x {} \; ; \
    fi

# ============================================================
# Verify installation
# ============================================================

RUN echo "============================================================" && \
    echo "Checking NanoHIV-DR container" && \
    echo "============================================================" && \
    echo "" && \
    echo "Python:" && \
    python3 --version && \
    echo "" && \
    echo "Dorado:" && \
    dorado --version && \
    echo "" && \
    echo "Minimap2:" && \
    micromamba run -n base minimap2 --version && \
    echo "" && \
    echo "Samtools:" && \
    micromamba run -n base samtools --version | head -n 1 && \
    echo "" && \
    echo "Seqtk:" && \
    micromamba run -n base seqtk 2>&1 | head -n 1 && \
    echo "" && \
    echo "NanoQ:" && \
    micromamba run -n base nanoq --version && \
    echo "" && \
    echo "Medaka:" && \
    micromamba run -n base medaka --version && \
    echo "" && \
    echo "MAFFT:" && \
    micromamba run -n base mafft --version | head -n 1 && \
    echo "" && \
    echo "RAxML:" && \
    micromamba run -n base raxmlHPC --version 2>&1 | head -n 1 && \
    echo "" && \
    echo "BCFtools:" && \
    micromamba run -n base bcftools --version | head -n 1 && \
    echo "" && \
    echo "SanitizeMe:" && \
    micromamba run -n base sanitizeme --help >/dev/null && \
    echo "sanitizeme OK" && \
    echo "" && \
    echo "REPORT:" && \
    test -x /opt/REPORT/preprocessing.sh && \
    echo "/opt/REPORT/preprocessing.sh OK" && \
    echo "" && \
    echo "============================================================" && \
    echo "NanoHIV-DR container OK" && \
    echo "============================================================"

# ============================================================
# Working directory
# ============================================================

WORKDIR /data

# ============================================================
# Default command
# ============================================================

CMD ["bash"]
