include { DORADO_BASECALL } from './modules/dorado_basecall'
include { DORADO_DEMUX }    from './modules/dorado_demux'
include { REMOVEHOST }      from './modules/removehost'
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
     * 3. Remove human/host reads
     * ---------------------------------------------------------
     */
    host_removed = REMOVEHOST(demultiplexed)


    /*
     * ---------------------------------------------------------
     * 4. Quality filtering
     * ---------------------------------------------------------
     *
     * Expected output:
     *
     *     sample.fastq.gz
     *
     */
    filtered = NANOQ(host_removed)


    /*
     * ---------------------------------------------------------
     * 5. HIV-1 pol reference
     * ---------------------------------------------------------
     *
     * HXB2-pol.fasta:
     *     used by Medaka as the draft/reference sequence
     *
     * HXB2-pol.mmi:
     *     pre-built minimap2 index used for mapping
     *
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
     * 6. Map filtered FASTQ to HXB2-pol
     * ---------------------------------------------------------
     *
     * Input:
     *
     *     HXB2-pol.mmi
     *     filtered FASTQ
     *
     * Output:
     *
     *     sample.bam
     *     sample.bam.bai
     *
     */
    minimap_inputs = filtered
        .combine(hiv_index)
        .map { reads, index ->
            tuple(index, reads)
        }

    bam = MINIMAP2(minimap_inputs)


    /*
     * ---------------------------------------------------------
     * 7. Medaka consensus polishing
     * ---------------------------------------------------------
     *
     * Medaka receives:
     *
     *     sample.bam
     *     sample.bam.bai
     *     HXB2-pol.fasta
     *
     * and produces:
     *
     *     polished consensus FASTA
     *
     */
    polished = MEDAKA(
        bam,
        hiv_reference
    )


    /*
     * ---------------------------------------------------------
     * 8. CodFreq analysis
     * ---------------------------------------------------------
     *
     * CodFreq operates directly on the filtered FASTQ.
     *
     * It uses its own minimap2-based alignment against
     * the HIV reference/profile.
     *
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