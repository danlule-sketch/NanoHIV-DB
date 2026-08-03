process MEDAKA {

    tag "${barcode}"

    publishDir "${params.outdir}/06_medaka", mode: "copy"


    input:
    tuple val(barcode), path(bam), path(reference)


    output:
    path "${barcode}_consensus.fasta"


    script:
    """
    echo "Running Medaka for ${barcode}"

    # Ensure BAM is coordinate sorted
    samtools sort \
        -@ ${task.cpus} \
        -o ${barcode}.sorted.bam \
        ${bam}

    samtools index ${barcode}.sorted.bam


    # Generate consensus sequence
    medaka_consensus \
        -i ${barcode}.sorted.bam \
        -d ${reference} \
        -o medaka_${barcode} \
        -t ${task.cpus} \
        -m ${params.medaka_model}


    # Rename final consensus
    cp medaka_${barcode}/consensus.fasta \
       ${barcode}_consensus.fasta
    """
}