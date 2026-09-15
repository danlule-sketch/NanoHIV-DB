process CODFREQ {

    tag "${bam.simpleName}"

    container 'nanohiv-dr-cpu:latest'

    cpus params.threads

    publishDir "${params.outdir}/08_codfreq",
        mode: 'copy',
        overwrite: true

    input:

    tuple path(bam), path(bai), path(profile)

    output:

    path "*.codfreq.tsv",
        emit: codfreq_results

    script:

    """
    set -euo pipefail

    echo "============================================================"
    echo " CODFREQ"
    echo "============================================================"
    echo ""

    echo "Input BAM:     ${bam}"
    echo "Input BAI:     ${bai}"
    echo "Profile:       ${profile}"
    echo ""

    command -v sam2codfreq

    sam2codfreq \
        "${bam}" \
        -r "${profile}"

    echo ""
    echo "CodFreq completed."
    echo ""

    find . \
        -maxdepth 1 \
        -type f \
        -printf '    %f\\n'

    if ! find . \
        -maxdepth 1 \
        -type f \
        -name "*.codfreq.tsv" \
        | grep -q .; then

        echo "ERROR: No *.codfreq.tsv output was produced."
        ls -lah
        exit 1
    fi

    echo ""
    echo "============================================================"
    echo " CODFREQ COMPLETE"
    echo "============================================================"
    """
}
