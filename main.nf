include { DORADO_BASECALL } from './modules/dorado_basecall'
include { DORADO_DEMUX }    from './modules/dorado_demux'
include { SANITIZEME }      from './modules/sanitizeme'
include { NANOQ }           from './modules/nanoq'
include { MINIMAP2 }        from './modules/minimap2'
include { MEDAKA }          from './modules/medaka'
include { CODFREQ }         from './modules/codfreq'
include { REPORT }          from './modules/report'


workflow {

    /*
     * ---------------------------------------------------------
     * 1. Basecalling
     * ---------------------------------------------------------
     */
    basecalled = DORADO_BASECALL(params.pod5)


    /*
     * ---------------------------------------------------------
     * 2. Demultiplex samples
     * ---------------------------------------------------------
     */
    demultiplexed = DORADO_DEMUX(basecalled)


    /*
     * ---------------------------------------------------------
     * 3. Remove host DNA
     * ---------------------------------------------------------
     *
     * SanitizeMe removes reads mapping to host DNA.
     *
     * Input:
     *     demultiplexed FASTQ
     *
     * Output:
     *     host-depleted FASTQ
     *
     */
    host_removed = SANITIZEME(demultiplexed)


    /*
     * ---------------------------------------------------------
     * 4. Quality filtering
     * ---------------------------------------------------------
     */
    filtered = NANOQ(host_removed)


    /*
     * ---------------------------------------------------------
     * 5. HIV-1 pol reference
     * ---------------------------------------------------------
     */
    hiv_reference = channel.fromPath(
        params.hiv_ref,
        checkIfExists: true
    )

    hiv_index = channel.fromPath(
        params.hiv_index,
        checkIfExists: true
    )


    /*
     * ---------------------------------------------------------
     * 6. Map filtered reads to HIV-1 pol
     * ---------------------------------------------------------
     */
    minimap_inputs = filtered
        .combine(hiv_index)
        .map { reads, index ->
            tuple(index, reads)
        }

    alignment = MINIMAP2(minimap_inputs)


    /*
     * ---------------------------------------------------------
     * 7. Medaka consensus polishing
     * ---------------------------------------------------------
     *
     * MINIMAP2 produces:
     *     BAM
     *     BAM index
     *
     * Extract the BAM and combine it with the
     * HXB2-pol reference FASTA.
     *
     */
    bam = alignment.map { bam_file, bai_file ->
        bam_file
    }

    medaka_inputs = bam
        .combine(hiv_reference)
        .map { bam_file, reference ->
            tuple(bam_file, reference)
        }

    polished = MEDAKA(medaka_inputs)


    /*
     * ---------------------------------------------------------
     * 8. CodFreq analysis
     * ---------------------------------------------------------
     */
    codfreq = CODFREQ(
        filtered
    )


    /*
     * ---------------------------------------------------------
     * 9. Final reporting
     * ---------------------------------------------------------
     */
    REPORT(
        polished,
        params.metadata
    )
}
