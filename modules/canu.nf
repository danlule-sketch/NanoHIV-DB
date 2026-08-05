process CANU {

    tag "${reads.simpleName}"

    cpus params.threads

    publishDir "${params.outdir}/05_canu", mode: "copy"

    input:
    path reads

    output:
    path "${reads.simpleName}.contigs.fasta"

    script:
    """
    canu \
        -p ${reads.simpleName} \
        -d canu_${reads.simpleName} \
        genomeSize=${params.genomeSize} \
        useGrid=false \
        maxThreads=${task.cpus} \
        -nanopore ${reads}

    cp \
        canu_${reads.simpleName}/${reads.simpleName}.contigs.fasta \
        .
    """
}