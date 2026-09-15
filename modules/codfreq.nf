process CODFREQ {

    tag "${bam.simpleName}"

    cpus params.threads

    publishDir "${params.outdir}/08_codfreq",
        mode: 'copy',
        overwrite: true

    input:

    tuple path(bam), path(bai), path(profile)

    output:

    path "*.codfreq",
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

    if ! command -v sam2codfreq >/dev/null 2>&1; then
        echo "ERROR: sam2codfreq is not installed in the container."
        echo "Container: nanohiv-dr-cpu:latest"
        exit 127
    fi

    sam2codfreq \
        "${bam}" \
        -r "${profile}"

    echo ""
    echo "CodFreq completed."
    echo ""

    if ! find . -maxdepth 1 -type f -name "*.codfreq" | grep -q .; then
        echo "ERROR: No *.codfreq output was produced."
        ls -lah
        exit 1
    fi

    echo ""
    echo "============================================================"
    echo " CODFREQ COMPLETE"
    echo "============================================================"
    """
}
