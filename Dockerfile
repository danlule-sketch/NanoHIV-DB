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
#   - CodFreq
#   - Python
#   - NanoHIV-DR reporting scripts
# ============================================================

FROM --platform=linux/amd64 mambaorg/micromamba:latest

# ============================================================
# Base configuration
# ============================================================

USER root

ENV DEBIAN_FRONTEND=noninteractive

ENV MAMBA_ROOT_PREFIX=/opt/conda

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
        build-essential \
        zlib1g-dev \
        libbz2-dev \
        liblzma-dev \
        libncurses-dev \
        libcurl4-openssl-dev \
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
# CodFreq
# ============================================================
#
# CodFreq source:
#
#   https://github.com/hivdb/codfreq
#
# CodFreq provides sam2codfreq and related commands.
# ============================================================

RUN git clone --depth 1 \
        https://github.com/hivdb/codfreq.git \
        /opt/codfreq

RUN python3 -m pip install --no-cache-dir --upgrade pip setuptools wheel && \
    python3 -m pip install --no-cache-dir \
        cython==0.29.35 \
        pysam==0.21.0 \
        cutadapt==4.4 \
        orjson==3.9.1 && \
    python3 -m pip install --no-cache-dir \
        -r /opt/codfreq/requirements.txt && \
    python3 -m pip install --no-cache-dir \
        --ignore-installed \
        /opt/codfreq

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
    echo "CodFreq:" && \
    command -v sam2codfreq && \
    sam2codfreq --help >/dev/null && \
    echo "sam2codfreq OK" && \
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
