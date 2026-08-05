include { DORADO_BASECALL } from './modules/dorado_basecall'
include { DORADO_DEMUX }    from './modules/dorado_demux'
include { REMOVEHOST }      from './modules/removehost'
include { NANOQ }           from './modules/nanoq'
include { CANU }            from './modules/canu'
include { MEDAKA }          from './modules/medaka'
include { MINIMAP2 }        from './modules/minimap2'
include { CODFREQ }         from './modules/codfreq'
include { REPORT }          from './modules/report'


workflow {

    /*
     * Basecalling
     */
    basecalled = DORADO_BASECALL(params.pod5)

    /*
     * Demultiplex samples
     */
    demultiplexed = DORADO_DEMUX(basecalled)

    /*
     * Remove host reads
     */
    host_removed = REMOVEHOST(demultiplexed)

    /*
     * Quality filtering
     */
    filtered = NANOQ(host_removed)

    /*
     * De novo assembly
     */
    contigs = CANU(filtered)

    /*
     * Consensus polishing
     */
    polished = MEDAKA(contigs, filtered)

    /*
     * Map reads back to polished consensus
     */
    minimap_inputs = polished
        .combine(filtered)
        .map { reference, reads ->

            def barcode = reference.baseName.split('_')[0]

            tuple(
                barcode,
                reference,
                reads
            )
        }

    bam = MINIMAP2(
        minimap_inputs,
        params.threads
    )

    /*
     * Codon frequency analysis
     */
    codfreq = CODFREQ(bam)

    /*
     * Final reporting
     *
     * preprocessing.sh performs:
     *   - Sierra-local drug resistance analysis
     *   - DOCX report generation
     *   - Drug-resistance summary table
     *   - MAFFT alignment
     *   - RAxML phylogeny
     *   - Tree visualisation
     */
    REPORT(
        polished,
        params.metadata
    )

}