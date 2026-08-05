process MEDAKA {

    tag "${bam.simpleName}"

    cpus 8

    publishDir "${params.outdir}/07_medaka", mode: 'copy'

    input:
    tuple path(bam), path(reference)

    output:
    path "consensus.fasta"

    script:
    """
    medaka_consensus \
        -i ${bam} \
        -d ${reference} \
        -o medaka \
        -t ${task.cpus} \
        -m ${params.medaka_model}

    cp medaka/consensus.fasta consensus.fasta
    """
}