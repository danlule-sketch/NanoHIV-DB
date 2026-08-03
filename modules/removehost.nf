process REMOVEHOST {

    tag "Removing human host reads"

    publishDir "${params.outdir}/04_removehost", mode: "copy"

    input:
    path fastq_dir
    path human_reference

    output:
    path "host_removed"

    script:
    """
    mkdir -p host_removed

    for f in ${fastq_dir}/*.fastq; do

        base=\$(basename "\$f" .fastq)

        echo "Processing \$f"

        minimap2 \
            -ax map-ont \
            -t ${params.threads} \
            ${human_reference} \
            "\$f" \
            > "\${base}.sam"

        samtools view \
            -f 4 \
            "\${base}.sam" | \
            cut -f1 | \
            sort | \
            uniq > "\${base}_unmapped_ids.txt"

        seqtk subseq \
            "\$f" \
            "\${base}_unmapped_ids.txt" \
            > "host_removed/\${base}_filtered.fastq"

        rm "\${base}.sam"
        rm "\${base}_unmapped_ids.txt"

    done

    echo "Human host removal completed."
    """
}