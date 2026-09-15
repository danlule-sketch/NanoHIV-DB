process CODFREQ {

    tag "${bam.simpleName}"

    cpus 8

    container "hivdb/codfreq-runner:latest"

    publishDir "${params.outdir}/08_codfreq",
        mode: 'copy',
        overwrite: true

    input:

    path bam

    path profile

    output:

    path "*.codfreq.gz",
        emit: codfreq

    script:

    """
    set -euo pipefail

    echo "============================================================"
    echo " CodFreq"
    echo "============================================================"
    echo "Input BAM:  ${bam}"
    echo "Profile:    ${profile}"
    echo "Threads:    ${task.cpus}"
    echo ""

    # ----------------------------------------------------------
    # Prepare CodFreq input directory
    # ----------------------------------------------------------

    mkdir -p codfreq_input

    cp ${bam} codfreq_input/


    # ----------------------------------------------------------
    # Run CodFreq
    # ----------------------------------------------------------
    #
    # align-all-local expects:
    #
    #     -r <PROFILE_PATH>
    #     -d <INPUT_DIRECTORY>
    #
    # The HIV-1 profile is supplied as HIV1.json.
    #
    # ----------------------------------------------------------

    bin/align-all-local \
        -r ${profile} \
        -d codfreq_input


    # ----------------------------------------------------------
    # Locate CodFreq output
    # ----------------------------------------------------------

    echo ""
    echo "Searching for CodFreq output..."
    echo ""

    CODFREQ_FILE=\$(find codfreq_input \
        -maxdepth 2 \
        -type f \
        -name "*.codfreq.gz" \
        | head -n 1)


    if [[ -z "\$CODFREQ_FILE" ]]; then

        echo ""
        echo "ERROR: CodFreq did not produce a .codfreq.gz file."
        echo ""

        echo "Contents of codfreq_input:"
        find codfreq_input \
            -maxdepth 3 \
            -type f \
            -print \
            -exec ls -lh {} \\;

        echo ""

        exit 1

    fi


    # ----------------------------------------------------------
    # Copy result to process working directory
    # ----------------------------------------------------------

    cp "\$CODFREQ_FILE" .


    # ----------------------------------------------------------
    # Verify output
    # ----------------------------------------------------------

    if ! compgen -G "*.codfreq.gz" > /dev/null; then

        echo ""
        echo "ERROR: Failed to copy CodFreq output."
        echo ""

        exit 1

    fi


    echo ""
    echo "============================================================"
    echo " CodFreq analysis complete"
    echo "============================================================"
    echo ""

    echo "Output:"
    ls -lh *.codfreq.gz

    echo ""

    echo "============================================================"
    """
}
