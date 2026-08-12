process NANOQ {

    tag "${reads.simpleName}"

    publishDir "${params.outdir}/04_filtered", mode: 'copy'

    input:
    path reads

    output:
    path "${reads.simpleName}.trimmed.fastq"

    script:
    """
    nanoq \
        ${reads} \
        -q ${params.min_quality} \
        -l ${params.min_length} \
        -m ${params.max_length} \
        > ${reads.simpleName}.trimmed.fastq
    """
}