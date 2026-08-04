process CANU {

    tag "${reads.simpleName}"

    cpus 8

    publishDir "${params.outdir}/05_canu", mode: 'copy'

    input:
    path reads

    output:
    path "${reads.simpleName}.contigs.fasta"

    script:
    """
    canu \
        -p ${reads.simpleName} \
        -d canu \
        genomeSize=${params.genomeSize} \
        -nanopore ${reads}

    cp canu/${reads.simpleName}.contigs.fasta .
    """
}