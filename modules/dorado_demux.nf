process DORADO_DEMUX {

    tag "Demultiplexing"

    publishDir "${params.outdir}/02_demultiplexed", mode: "copy"

    input:
    path bam_dir

    output:
    path "demultiplexed"

    script:
    """
    dorado demux \
        --kit-name ${params.kit_name} \
        --emit-fastq \
        --output-dir demultiplexed \
        ${bam_dir}
    """
}