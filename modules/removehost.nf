process REMOVEHOST {

    tag "${reads.simpleName}"

    cpus 8

    publishDir "${params.outdir}/03_removehost", mode: 'copy'

    input:
    path reads

    output:
    path "${reads.simpleName}_filtered.fastq"

    script:
    """
    minimap2 \
        -ax map-ont \
        -t ${task.cpus} \
        ${params.human_index} \
        ${reads} \
        | samtools view -f 4 \
        | cut -f1 \
        | sort -u \
        > ids.txt

    seqtk subseq \
        ${reads} \
        ids.txt \
        > ${reads.simpleName}_filtered.fastq
    """
}