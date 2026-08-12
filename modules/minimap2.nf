process MINIMAP2 {

    tag "${reads.simpleName}"

    cpus params.threads

    publishDir "${params.outdir}/06_minimap2", mode: 'copy'

    input:
    tuple path(index), path(reads)

    output:
    path "${reads.simpleName}.bam"
    path "${reads.simpleName}.bam.bai"

    script:
    """
    minimap2 \
        -ax map-ont \
        -t ${task.cpus} \
        ${index} \
        ${reads} \
        | samtools sort \
        -@ ${task.cpus} \
        -o ${reads.simpleName}.bam

    samtools index ${reads.simpleName}.bam
    """
}
