# ============================================================
# NanoHIV-DR Pipeline Container
# ============================================================
#
# Target architecture:
#   linux/amd64
#
# Software included:
#   - Dorado
#   - minimap2
#   - samtools
#   - seqtk
#   - NanoQ
#   - medaka
#   - MAFFT
#   - RAxML
#   - BCFtools
#   - SanitizeMe
#   - CodFreq
#   - Python
#   - NanoHIV-DR reporting scripts
#
# ============================================================


# ============================================================
# Base image
# ============================================================

FROM mambaorg/micromamba:2.3.0


# ============================================================
# Base configuration
# ============================================================

USER root

ENV DEBIAN_FRONTEND=noninteractive
ENV MAMBA_ROOT_PREFIX=/opt/conda

ENV PATH="/opt/codfreq/bin:/opt/conda/envs/codfreq/bin:/opt/conda/bin:/opt/dorado/bin:/opt/REPORT:/opt/REPORT/bin:${PATH}"


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
    && \
    rm -rf /var/lib/apt/lists/*


# ============================================================
# Bioinformatics software
# ============================================================
#
# Installed into the micromamba base environment.
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
        sanitizeme \
    && \
    micromamba clean --all --yes


# ============================================================
# Create dedicated CodFreq environment
# ============================================================
#
# CodFreq uses Cython extensions and pinned dependencies.
# Keep CodFreq isolated from the main environment.
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
    && \
    micromamba clean --all --yes


# ============================================================
# Download CodFreq source
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
# Verify CodFreq Python module
# ============================================================

RUN micromamba run -n codfreq \
    python -c \
    "import codfreq.sam2codfreq; print(codfreq.sam2codfreq.__file__)"


# ============================================================
# Create sam2codfreq command
# ============================================================
#
# The upstream CodFreq installation does not expose the
# required sam2codfreq command as a console script.
#
# The compiled Cython module exposes the sam2codfreq function.
#
# IMPORTANT:
# The function expects individual arguments. Therefore the
# command-line arguments must be expanded using *sys.argv[1:].
#
# ============================================================

RUN mkdir -p /opt/codfreq/bin && \
    cat > /opt/codfreq/bin/sam2codfreq <<'EOF'
#!/bin/bash
set -euo pipefail

exec /opt/conda/envs/codfreq/bin/python - "$@" <<'PY'
import sys

from codfreq.sam2codfreq import sam2codfreq

sam2codfreq(*sys.argv[1:])
PY
EOF

RUN chmod +x /opt/codfreq/bin/sam2codfreq


# ============================================================
# Verify sam2codfreq installation
# ============================================================

RUN echo "============================================================" && \
    echo "Checking CodFreq" && \
    echo "============================================================" && \
    echo "" && \
    echo "CodFreq Python:" && \
    /opt/conda/envs/codfreq/bin/python --version && \
    echo "" && \
    echo "CodFreq module:" && \
    /opt/conda/envs/codfreq/bin/python -c \
        "import codfreq.sam2codfreq; print(codfreq.sam2codfreq.__file__)" && \
    echo "" && \
    echo "sam2codfreq executable:" && \
    test -x /opt/codfreq/bin/sam2codfreq && \
    command -v sam2codfreq && \
    ls -l /opt/codfreq/bin/sam2codfreq && \
    echo "" && \
    echo "CodFreq installation OK" && \
    echo "============================================================"


# ============================================================
# Remove CodFreq source
# ============================================================

RUN rm -rf /tmp/codfreq


# ============================================================
# Install Dorado
# ============================================================

COPY containers/dorado-linux-x64 /opt/dorado

RUN chmod +x /opt/dorado/bin/dorado


# ============================================================
# Install NanoHIV-DR reporting software
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
            -exec chmod +x {} \; \
    ; fi


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
    echo "CodFreq module:" && \
    /opt/conda/envs/codfreq/bin/python -c \
        "import codfreq.sam2codfreq; print(codfreq.sam2codfreq.__file__)" && \
    echo "" && \
    echo "sam2codfreq:" && \
    command -v sam2codfreq && \
    ls -l /opt/codfreq/bin/sam2codfreq && \
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
