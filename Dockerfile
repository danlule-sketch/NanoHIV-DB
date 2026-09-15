# ============================================================
# NanoHIV-DR pipeline container
# ============================================================
#
# Target architecture:
#   linux/amd64
#
# Includes:
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
#   - CodFreq
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
        gcc \
        g++ \
        make \
        python3 \
        python3-pip \
        python3-dev \
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

COPY containers/dorado-linux-x64 /opt/dorado

RUN chmod +x /opt/dorado/bin/dorado

# ============================================================
# CodFreq
# ============================================================
#
# Install CodFreq directly from the official GitHub repository.
#
# CodFreq uses Cython extensions and therefore requires:
#   - gcc
#   - g++
#   - make
#   - python3-dev
#
# The repository's setup.py installs the required Python
# dependencies and builds the Cython extensions.
# ============================================================

RUN git clone --depth 1 \
        https://github.com/hivdb/codfreq.git \
        /opt/codfreq && \
    cd /opt/codfreq && \
    python3 -m pip install --no-cache-dir --break-system-packages \
        cython==0.29.35 \
        && \
    python3 -m pip install --no-cache-dir --break-system-packages \
        -r requirements.txt \
        && \
    python3 -m pip install --no-cache-dir --break-system-packages \
        .

# ============================================================
# NanoHIV-DR reporting software
# ============================================================

COPY REPORT /opt/REPORT

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
    command -v fastq2codfreq && \
    fastq2codfreq --help >/dev/null && \
    echo "fastq2codfreq OK" && \
    echo "" && \
    echo "CodFreq Python module:" && \
    python3 -c "import codfreq; print(codfreq.__file__)" && \
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
