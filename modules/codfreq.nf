process CODFREQ {

    tag "${reads.simpleName}"

    cpus 8

    container "hivdb/codfreq-runner:latest"

    publishDir "${params.outdir}/08_codfreq",
        mode: 'copy',
        overwrite: true

    input:

    path reads

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
    echo "Input:       ${reads}"
    echo "Profile:     ${profile}"
    echo "Threads:     ${task.cpus}"
    echo ""

    mkdir -p codfreq_input

    cp ${reads} codfreq_input/

    bin/align-all-local \
        -r ${profile} \
        -d codfreq_input

    echo ""
    echo "CodFreq analysis complete."
    echo ""

    find codfreq_input \
        -maxdepth 1 \
        -type f \
        -name "*.codfreq.gz" \
        -exec cp {} . \\;

    if ! compgen -G "*.codfreq.gz" > /dev/null; then

        echo ""
        echo "ERROR: CodFreq did not produce a .codfreq.gz file."
        echo ""

        ls -lah codfreq_input

        exit 1

    fi

    echo "CodFreq output:"
    ls -lh *.codfreq.gz

    echo ""
    echo "============================================================"
    """
}
