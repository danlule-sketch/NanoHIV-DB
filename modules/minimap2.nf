process MINIMAP2 {

    tag "${barcode}"

    publishDir "${params.outdir}/07_minimap2", mode: "copy"

    input:
    tuple val(barcode), path(reference), path(reads)

    val threads

    output:
    path "${barcode}.sorted.bam"
    path "${barcode}.sorted.bam.bai"

    script:
    """
    echo "Processing ${barcode}"

    # Index reference if needed
    samtools faidx ${reference}

    minimap2 -d ${reference}.mmi ${reference}

    # Align reads
    minimap2 -ax map-ont \
        ${reference}.mmi \
        ${reads} \
        | samtools sort \
        -@ ${threads} \
        -o ${barcode}.sorted.bam

    # Index BAM
    samtools index ${barcode}.sorted.bam
    """
}