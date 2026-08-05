process CODFREQ {

    container "hivdb/codfreq:latest"

    publishDir "${params.outdir}/08_codfreq", mode: 'copy'

    input:
    tuple path(bam), path(reference)

    output:
    path "*.codfreq"

    script:
    """
    generate_codfreq \
        --bam ${bam} \
        --ref ${reference} \
        --out codfreq
    """
}