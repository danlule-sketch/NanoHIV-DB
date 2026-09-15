process CODFREQ {

    tag "${sample_id}"

    publishDir "${params.outdir}/08_codfreq",
        mode: 'copy',
        overwrite: true

    input:

    tuple val(sample_id), path(reads)
    path profile

    output:

    tuple val(sample_id), path("*.codfreq"),
        emit: codfreq_results

    script:

    """
    set -euo pipefail

    mkdir -p codfreq_work

    cp ${reads} codfreq_work/

    cp ${profile} codfreq_work/HIV1.json

    fastq2codfreq \
        codfreq_work \
        --program minimap2 \
        --profile codfreq_work/HIV1.json \
        --workers ${task.cpus}

    find codfreq_work \
        -maxdepth 1 \
        -type f \
        -name '*.codfreq' \
        -exec cp {} . \\;

    if ! compgen -G '*.codfreq' > /dev/null; then
        echo "ERROR: CodFreq did not produce a .codfreq file."
        echo "Contents of codfreq_work:"
        find codfreq_work -maxdepth 2 -type f -print
        exit 1
    fi
    """
}
