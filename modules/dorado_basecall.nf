process DORADO_BASECALL {

    tag "Basecalling"

    publishDir "${params.outdir}/01_basecalled", mode: "copy"

    input:
    path pod5_dir

    output:
    path "all_reads.bam"

    script:
    """
    dorado basecaller \
        ${params.dorado_model} \
        ${pod5_dir} \
        --device ${params.device} \
        --kit-name ${params.kit_name} \
        > all_reads.bam
    """
}