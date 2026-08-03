process NANOQ {

    tag "NanoQ filtering"

    publishDir "${params.outdir}/03_filtered", mode: "copy"

    input:
    path fastq_dir

    output:
    path "filtered"

    script:
    """
    mkdir -p filtered

    for f in ${fastq_dir}/*barcode*.fastq ${fastq_dir}/*barcode*.fastq.gz; do
        [ -e "\$f" ] || continue

        base=\$(basename "\$f")
        base=\${base%%.*}

        echo "Processing \$f"

        nanoq \
            -i "\$f" \
            -o "filtered/\${base}.trimmed.fastq" \
            -q ${params.min_quality} \
            -l ${params.min_length} \
            -m ${params.max_length}
    done

    echo "All barcode FASTQ files processed."
    """
}