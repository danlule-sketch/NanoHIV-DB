include { DORADO_BASECALL } from './modules/dorado_basecall'
include { DORADO_DEMUX }    from './modules/dorado_demux'
include { REMOVEHOST }      from './modules/removehost'
include { NANOQ }           from './modules/nanoq'
include { CANU }            from './modules/canu'
include { MEDAKA }          from './modules/medaka'
include { MINIMAP2 }        from './modules/minimap2'
include { SIERRALOCAL }     from './modules/sierralocal'
include { CODFREQ }         from './modules/codfreq'
include { REPORT }          from './modules/report'


workflow {


    /*
    Basecalling
    */

    basecalled = DORADO_BASECALL(params.pod5)


    /*
    Demultiplexing
    */

    demux = DORADO_DEMUX(basecalled)


    /*
    Remove human reads
    */

    host_removed = REMOVEHOST(demux)


    /*
    Quality filtering
    */

    filtered = NANOQ(host_removed)


    /*
    De novo assembly
    */

    contigs = CANU(filtered)


    /*
    Polishing
    */

    polished = MEDAKA(contigs, filtered)



    /*
    Prepare minimap2 inputs
    Reference = Medaka consensus
    Reads = filtered nanopore reads
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


    /*
    Mapping reads back to polished HIV reference
    */

    bam = MINIMAP2(
        minimap_inputs,
        params.threads
    )


    /*
    HIVdb resistance scoring
    */

    resistance = SIERRALOCAL(polished)


    /*
    HIVdb NGS codon frequency
    */

    codfreq = CODFREQ(bam)


    /*
    Reports
    */

    REPORT(resistance, codfreq)

}