process REPORT {

    tag "${fasta.simpleName}"

    cpus 4

    publishDir "${params.outdir}/09_reports", mode: 'copy'

    input:
    path fasta
    path metadata

    output:
    path "results_*"

    script:
    """
    cp ${fasta} input.fasta
    cp ${metadata} metadata.tsv

    /opt/REPORT/preprocessing.sh \
        -f input.fasta \
        -t metadata.tsv

    cp -r results_* .
    """
}