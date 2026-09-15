process CODFREQ {

    tag "${bam.simpleName}"

    cpus params.threads

    publishDir "${params.outdir}/08_codfreq",
        mode: 'copy',
        overwrite: true

    input:

    path bam
    path bai
    path profile

    output:

    path "*.codfreq",
        emit: codfreq_results

    script:

    """
    set -euo pipefail

    echo ""
    echo "============================================================"
    echo " CODFREQ"
    echo "============================================================"
    echo ""

    echo "Input BAM:"
    echo "    ${bam}"

    echo ""

    echo "Input BAI:"
    echo "    ${bai}"

    echo ""

    echo "Profile:"
    echo "    ${profile}"

    echo ""

    echo "Running sam2codfreq..."

    echo ""

    command -v sam2codfreq || {
        echo "ERROR: sam2codfreq is not installed in the container."
        echo ""
        echo "Container: nanohiv-dr-cpu:latest"
        exit 127
    }

    sam2codfreq \
        "${bam}" \
        -r "${profile}"

    echo ""
    echo "CodFreq command completed."
    echo ""

    echo "Output files:"
    echo ""

    find . \
        -maxdepth 1 \
        -type f \
        -printf '    %f\\n'

    echo ""

    if ! find . \
        -maxdepth 1 \
        -type f \
        -name "*.codfreq" \
        | grep -q .; then

        echo "ERROR: No *.codfreq file was produced."

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
