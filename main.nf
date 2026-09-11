include { DORADO_BASECALL } from './modules/dorado_basecall'
include { DORADO_DEMUX } from './modules/dorado_demux'
include { SANITIZEME } from './modules/sanitizeme'
include { NANOQ } from './modules/nanoq'
include { MINIMAP2 } from './modules/minimap2'
include { MEDAKA } from './modules/medaka'
include { CODFREQ } from './modules/codfreq'
include { REPORT } from './modules/report'


workflow {

    /*
     * ---------------------------------------------------------
     * 0. Help menu
     * ---------------------------------------------------------
     */
    if (params.help) {

        log.info """
============================================================
                    NanoHIV-DR Pipeline
============================================================

USAGE:

    nextflow run main.nf --pod5 <POD5_DIRECTORY> --metadata <METADATA_FILE>


REQUIRED OPTIONS:

    --pod5
        Directory containing the POD5 input files.

    --metadata
        Metadata file containing sample/patient information.


OPTIONAL OPTIONS:

    --outdir
        Output directory.

        Default:
            results


    --threads
        Number of CPU threads.

        Default:
            8


DORADO OPTIONS:

    --dorado_model
        Dorado basecalling model.

        Default:
            dna_r10.4.1_e8.2_400bps_sup@v5.2.0


    --kit_name
        Oxford Nanopore sequencing kit.

        Default:
            SQK-NBD114-96


NANOQ OPTIONS:

    --min_quality
        Minimum read quality.

        Default:
            15


    --min_length
        Minimum read length.

        Default:
            800


    --max_length
        Maximum read length.

        Default:
            1200


HIV-1 REFERENCE:

    --hiv_ref
        HIV-1 pol reference FASTA.

        Default:
            references/HIV/HXB2-pol.fasta


    --hiv_index
        Minimap2 HIV-1 pol index.

        Default:
            references/HIV/HXB2-pol.mmi


MEDAKA:

    --medaka_model
        Medaka consensus model.

        Default:
            r1041_e82_400bps_sup_v5.2.0


EXAMPLES:

    Display this help menu:

        nextflow run main.nf --help


    Run the pipeline:

        nextflow run main.nf \\
            --pod5 data/pod5 \\
            --metadata references/Database_test.txt


    Run with custom output directory:

        nextflow run main.nf \\
            --pod5 /path/to/pod5 \\
            --metadata /path/to/metadata.tsv \\
            --outdir results


============================================================
"""

    } else {

        /*
         * ---------------------------------------------------------
         * 1. Validate user inputs
         * ---------------------------------------------------------
         */
        if (!params.pod5) {
            error "Missing required input: --pod5 <POD5_DIRECTORY>"
        }

        if (!params.metadata) {
            error "Missing required input: --metadata <METADATA_FILE>"
        }


        /*
         * ---------------------------------------------------------
         * 2. User input files
         * ---------------------------------------------------------
         */
        pod5_input = channel.fromPath(
            params.pod5,
            checkIfExists: true,
            type: 'dir'
        )

        metadata_input = channel.fromPath(
            params.metadata,
            checkIfExists: true,
            type: 'file'
        )


        /*
         * ---------------------------------------------------------
         * 3. HIV-1 pol reference
         * ---------------------------------------------------------
         */
        hiv_reference = channel.fromPath(
            params.hiv_ref,
            checkIfExists: true,
            type: 'file'
        )

        hiv_index = channel.fromPath(
            params.hiv_index,
            checkIfExists: true,
            type: 'file'
        )


        /*
         * ---------------------------------------------------------
         * 4. Basecalling
         * ---------------------------------------------------------
         */
        basecalled = DORADO_BASECALL(pod5_input)


        /*
         * ---------------------------------------------------------
         * 5. Demultiplex samples
         * ---------------------------------------------------------
         */
        demultiplexed = DORADO_DEMUX(basecalled)


        /*
         * ---------------------------------------------------------
         * 6. Remove host DNA
         * ---------------------------------------------------------
         */
        host_removed = SANITIZEME(demultiplexed)


        /*
         * ---------------------------------------------------------
         * 7. Quality filtering
         * ---------------------------------------------------------
         */
        filtered = NANOQ(host_removed)


        /*
         * ---------------------------------------------------------
         * 8. Map filtered reads to HIV-1 pol
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
         * 9. Medaka consensus polishing
         * ---------------------------------------------------------
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
         * 10. CodFreq analysis
         * ---------------------------------------------------------
         */
        codfreq = CODFREQ(filtered)


        /*
         * ---------------------------------------------------------
         * 11. Final reporting
         * ---------------------------------------------------------
         */
        REPORT(
            polished,
            metadata_input
        )
    }
}
