process SANITIZEME {

    tag "${reads.simpleName}"

    cpus 8

    publishDir "${params.outdir}/03_removehost", mode: 'copy'

    input:
    path reads
    path host_reference

    output:
    path "${reads.simpleName}_filtered.fastq"

    script:
    """
    mkdir -p sanitizeme_output

    SanitizeMe_CLI.py \
        -i . \
        -r ${host_reference} \
        -o sanitizeme_output \
        -t ${task.cpus} \
        --Nanopore

    cp sanitizeme_output/${reads.simpleName}_filtered.fastq \
       ${reads.simpleName}_filtered.fastq
    """
}
