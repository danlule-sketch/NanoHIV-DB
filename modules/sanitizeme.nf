process SANITIZEME {

    tag "${reads.simpleName}"

    cpus 8

    publishDir "${params.outdir}/03_removehost", mode: 'copy'

    input:
    path reads
    path human_reference

    output:
    path "${reads.simpleName}_filtered.fastq"

    script:
    """
    mkdir -p sanitizeme_input

    cp ${reads} sanitizeme_input/

    SanitizeMe_CLI.py \
        -i sanitizeme_input \
        -r ${human_reference} \
        -o . \
        -t ${task.cpus} \
        --Nanopore

    mv sanitizeme_input_filtered.fastq \
        ${reads.simpleName}_filtered.fastq
    """
}
