process CODFREQ {

    tag "${reads.simpleName}"

    cpus params.threads

    publishDir "${params.outdir}/08_codfreq",
        mode: 'copy',
        overwrite: true

    input:

    path reads
    path profile

    output:

    path "*.codfreq.tsv",
        emit: codfreq_results

    path "*.bam",
        emit: codfreq_bam,
        optional: true

    path "*.bam.bai",
        emit: codfreq_bai,
        optional: true

    script:

    """
    set -euo pipefail

    echo ""
    echo "============================================================"
    echo " CODFREQ"
    echo "============================================================"
    echo ""

    echo "Input FASTQ:"
    echo "    ${reads}"

    echo ""

    echo "Profile:"
    echo "    ${profile}"

    echo ""

    cp "${profile}" HIV1.json

    echo "Running:"
    echo ""

    echo "    fastq2codfreq . \\\\"
    echo "        --program minimap2 \\\\"
    echo "        --profile HIV1.json \\\\"
    echo "        --workers ${task.cpus}"

    echo ""

    fastq2codfreq \
        . \
        --program minimap2 \
        --profile HIV1.json \
        --workers ${task.cpus}

    echo ""
    echo "CodFreq command completed."
    echo ""

    echo "Output files:"

    find . \
        -maxdepth 1 \
        -type f \
        -printf '    %f\\n'

    echo ""

    if ! find . \
        -maxdepth 1 \
        -type f \
        -name "*.codfreq.tsv" \
        | grep -q .; then

        echo "ERROR: No *.codfreq.tsv file was produced."

        echo ""
        echo "Directory contents:"

        ls -lah

        exit 1
    fi

    echo ""
    echo "============================================================"
    echo " CODFREQ COMPLETE"
    echo "============================================================"
    echo ""
    """
}
