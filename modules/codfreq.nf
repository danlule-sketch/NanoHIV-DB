/*
 * ============================================================
 * CODFREQ
 * ============================================================
 *
 * Branch 3 of the NanoHIV-DR workflow.
 *
 * Input:
 *
 *     NanoQ filtered FASTQ
 *             +
 *     CodFreq HIV-1 profile
 *
 * Output:
 *
 *     *.codfreq.tsv
 *
 * Workflow:
 *
 *     NanoQ
 *       ↓
 *     CODFREQ
 *       ↓
 *     Codon-frequency results
 *
 * IMPORTANT:
 *
 * This process deliberately receives the NanoQ FASTQ.
 * It does NOT receive the BAM/BAI produced by Minimap2.
 *
 * ============================================================
 */

process CODFREQ {

    tag "${reads.simpleName}"

    container 'nanohiv-dr-cpu:latest'

    cpus params.threads

    publishDir "${params.outdir}/08_codfreq",
        mode: 'copy',
        overwrite: true


    input:

    tuple path(reads), path(profile)


    output:

    path "*.codfreq.tsv",
        emit: codfreq_results


    script:

    def sample = reads.simpleName
        .replaceFirst(/\.trimmed$/, '')

    """
    set -euo pipefail

    echo "============================================================"
    echo " CODFREQ"
    echo "============================================================"
    echo ""

    echo "Sample:"
    echo "    ${sample}"
    echo ""

    echo "Input FASTQ:"
    echo "    ${reads}"
    echo ""

    echo "CodFreq profile:"
    echo "    ${profile}"
    echo ""

    echo "Threads:"
    echo "    ${task.cpus}"
    echo ""


    /*
     * --------------------------------------------------------
     * Check CodFreq installation
     * --------------------------------------------------------
     */

    if ! command -v sam2codfreq >/dev/null 2>&1; then

        echo ""
        echo "ERROR: sam2codfreq was not found in PATH."
        echo ""

        echo "PATH:"
        echo "${PATH}"

        exit 1

    fi


    echo "CodFreq executable:"
    command -v sam2codfreq

    echo ""


    /*
     * --------------------------------------------------------
     * Run CodFreq
     * --------------------------------------------------------
     *
     * The FASTQ from NanoQ is the primary input for this
     * branch.
     *
     * The HIV1.json profile supplies the CodFreq analysis
     * configuration.
     *
     * --------------------------------------------------------
     */

    sam2codfreq \
        "${reads}" \
        -r "${profile}"


    /*
     * --------------------------------------------------------
     * Locate CodFreq output
     * --------------------------------------------------------
     */

    echo ""
    echo "CodFreq output files:"
    echo ""

    find . \
        -maxdepth 1 \
        -type f \
        -printf '    %f\\n'


    /*
     * --------------------------------------------------------
     * Validate output
     * --------------------------------------------------------
     */

    if ! find . \
        -maxdepth 1 \
        -type f \
        -name "*.codfreq.tsv" \
        | grep -q .; then

        echo ""
        echo "ERROR: No *.codfreq.tsv output was produced."
        echo ""

        ls -lah

        exit 1

    fi


    /*
     * --------------------------------------------------------
     * Rename output if CodFreq did not use the sample name
     * --------------------------------------------------------
     */

    codfreq_file=\$(find . \
        -maxdepth 1 \
        -type f \
        -name "*.codfreq.tsv" \
        | head -n 1)


    if [[ -z "\${codfreq_file}" ]]; then

        echo ""
        echo "ERROR: Could not locate CodFreq result."
        echo ""

        exit 1

    fi


    expected="./${sample}.codfreq.tsv"


    if [[ "\${codfreq_file}" != "\${expected}" ]]; then

        mv \
            "\${codfreq_file}" \
            "\${expected}"

    fi


    /*
     * --------------------------------------------------------
     * Final validation
     * --------------------------------------------------------
     */

    if [[ ! -s "${sample}.codfreq.tsv" ]]; then

        echo ""
        echo "ERROR: CodFreq result is empty."
        echo ""

        exit 1

    fi


    /*
     * --------------------------------------------------------
     * Complete
     * --------------------------------------------------------
     */

    echo ""
    echo "============================================================"
    echo " CODFREQ COMPLETE"
    echo "============================================================"
    echo ""

    echo "Sample:"
    echo "    ${sample}"
    echo ""

    echo "Result:"
    echo "    ${sample}.codfreq.tsv"
    echo ""

    ls -lh \
        "${sample}.codfreq.tsv"

    echo ""
    """
}
