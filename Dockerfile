# NanoHIV-DR pipeline container
# Target: linux/amd64

FROM mambaorg/micromamba:latest

USER root

ENV PATH="/opt/dorado/bin:/opt/REPORT:$PATH"

# Install system utilities
RUN apt-get update || true && \
    apt-get install -y --no-install-recommends \
    wget \
    curl \
    git \
    python3 \
    python3-pip \
    unzip \
    tar \
    gzip \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Install bioinformatics tools via conda
RUN micromamba install -y -n base \
    -c conda-forge \
    -c bioconda \
    minimap2 \
    samtools \
    seqtk \
    canu \
    medaka \
    mafft \
    raxml \
    bcftools \
    && micromamba clean --all --yes


# Copy Dorado
COPY containers/dorado-linux-x64 /opt/dorado

RUN chmod +x /opt/dorado/bin/dorado


# Copy HIV report pipeline
COPY REPORT /opt/REPORT

RUN chmod +x /opt/REPORT/preprocessing.sh && \
    chmod +x /opt/REPORT/bin/*.py


WORKDIR /data

CMD ["bash"]