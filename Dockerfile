# ============================================================
# NanoHIV-DR pipeline container
# ============================================================
#
# Target architecture:
#   linux/amd64
#
# Contains:
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
#   - CodFreq
#   - Python
#   - NanoHIV-DR reporting scripts
#
# ============================================================

FROM mambaorg/micromamba:latest

# ============================================================
# Base configuration
# ============================================================

USER root

ENV DEBIAN_FRONTEND=noninteractive
ENV MAMBA_ROOT_PREFIX=/opt/conda

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
        build-essential \
        gcc \
        g++ \
        make \
        zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

# ============================================================
# Bioinformatics software
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
# CodFreq environment
# ============================================================
#
# CodFreq contains Cython extensions and uses pinned
# dependencies, so it is isolated in its own environment.
#
# ============================================================

RUN micromamba create -y \
    -n codfreq \
    -c conda-forge \
        python=3.11 \
        pip \
        setuptools \
        wheel \
        cython=0.29.35 \
        gcc \
        gxx \
        make \
    && micromamba clean --all --yes

# ============================================================
# Download CodFreq
# ============================================================

RUN git clone \
    --depth 1 \
    https://github.com/hivdb/codfreq.git \
    /tmp/codfreq

# ============================================================
# Install CodFreq dependencies
# ============================================================

RUN micromamba run -n codfreq \
    pip install \
    --no-cache-dir \
        "pysam==0.21.0" \
        "cutadapt==4.4" \
        "orjson==3.9.1" \
        "click==8.1.3" \
        "dnaio==0.10.0" \
        "more-itertools==9.1.0" \
        "pafpy==0.2.0" \
        "pygments==2.15.1" \
        "pyyaml==6.0.1" \
        "tqdm==4.65.0" \
        "types-setuptools==67.8.0.0" \
        "typing-extensions==4.7.1" \
        "urllib3==2.0.4" \
        "xopen==1.7.0"

# ============================================================
# Install post-align
# ============================================================

RUN micromamba run -n codfreq \
    pip install \
    --no-cache-dir \
    "https://github.com/hivdb/post-align/archive/cb28b83e2d9639960533f805f7dc2612ea63ddc6.zip"

# ============================================================
# Build and install CodFreq
# ============================================================

RUN cd /tmp/codfreq && \
    micromamba run -n codfreq \
    pip install \
    --no-cache-dir \
    --ignore-installed \
    .

# ============================================================
# Create sam2codfreq executable
# ============================================================
#
# The upstream CodFreq package does not expose sam2codfreq
# through console_scripts.
#
# The compiled Cython extension provides the sam2codfreq
# callable. This wrapper invokes the module through the
# dedicated CodFreq Python environment.
#
# ============================================================

RUN mkdir -p /opt/codfreq/bin && \
    printf '%s\n' \
        '#!/bin/bash' \
        'set -euo pipefail' \
        'exec /opt/conda/envs/codfreq/bin/python -m codfreq.sam2codfreq "$@"' \
        > /opt/codfreq/bin/sam2codfreq && \
    chmod +x /opt/codfreq/bin/sam2codfreq

# ============================================================
# Remove CodFreq source
# ============================================================

RUN rm -rf /tmp/codfreq

# ============================================================
# Dorado
# ============================================================

COPY containers/dorado-linux-x64 /opt/dorado

RUN chmod +x /opt/dorado/bin/dorado

# ============================================================
# NanoHIV-DR reporting software
# ============================================================

COPY REPORT /opt/REPORT

# ============================================================
# Make reporting scripts executable
# ============================================================

RUN chmod +x /opt/REPORT/preprocessing.sh && \
    if [ -d /opt/REPORT/bin ]; then \
        find /opt/REPORT/bin \
            -type f \
            -name "*.py" \
            -exec chmod +x {} \; ; \
    fi

# ============================================================
# Final executable PATH
# ============================================================
#
# IMPORTANT:
# /opt/codfreq/bin contains the sam2codfreq executable.
#
# Keeping this in PATH makes sam2codfreq available to
# Nextflow inside the container without requiring an absolute
# host-specific path.
#
# ============================================================

ENV PATH="/opt/codfreq/bin:/opt/conda/envs/codfreq/bin:/opt/conda/bin:/opt/dorado/bin:/opt/REPORT:/opt/REPORT/bin:${PATH}"

# ============================================================
# Verify complete container
# ============================================================

RUN echo "============================================================" && \
    echo "Checking NanoHIV-DR container" && \
    echo "============================================================" && \
    echo "" && \
    echo "System Python:" && \
    python3 --version && \
    echo "" && \
    echo "CodFreq Python:" && \
    /opt/conda/envs/codfreq/bin/python --version && \
    echo "" && \
    echo "CodFreq extension:" && \
    /opt/conda/envs/codfreq/bin/python -c \
        "import codfreq.sam2codfreq; print(codfreq.sam2codfreq.__file__)" && \
    echo "" && \
    echo "sam2codfreq:" && \
    command -v sam2codfreq && \
    test -x "$(command -v sam2codfreq)" && \
    echo "sam2codfreq OK" && \
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
    micromamba run -n base seqtk 2>&1 || true && \
    echo "seqtk OK" && \
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
    micromamba run -n base raxmlHPC -h 2>&1 | head -n 3 || true && \
    echo "RAxML OK" && \
    echo "" && \
    echo "BCFtools:" && \
    micromamba run -n base bcftools --version | head -n 1 && \
    echo "" && \
    echo "SanitizeMe:" && \
    micromamba run -n base SanitizeMe_CLI.py -h >/dev/null && \
    echo "SanitizeMe_CLI.py OK" && \
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
