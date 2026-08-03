process CODFREQ {

    container 'hivdb/codfreq:latest'

    publishDir "${params.outdir}/codfreq", mode: "copy"

    input:
    path bam
    path reference

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