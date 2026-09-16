#!/usr/bin/env nextflow

/*
 * ============================================================
 * NanoHIV-DR
 * ============================================================
 *
 * Oxford Nanopore HIV drug-resistance workflow.
 *
 *
 * STAGE 1
 *
 * POD5
 *   ↓
 * Dorado basecalling
 *   ↓
 * Dorado demultiplexing
 *   ↓
 * SanitizeMe
 *   ↓
 * NanoQ
 *   │
 *   ├──────────────────────────────┐
 *   │                              │
 *   ▼                              ▼
 * Medaka                         Minimap2
 *   │                              │
 *   ▼                              ▼
 * Consensus FASTA                BAM + BAI
 *   │
 *   └──→ Human checkpoint
 *
 *
 * NanoQ FASTQ also feeds CodFreq independently:
 *
 * NanoQ FASTQ
 *   ↓
 * CodFreq
 *   ↓
 * Codon-frequency results
 *
 *
 * STAGE 2
 *
 * consensus.fasta
 *       +
 * metadata.tsv
 *       ↓
 * Metadata validation
 *       ↓
 * Clinical reporting
 *
 * ============================================================
 */


/*
 * ============================================================
 * PARAMETERS
 * ============================================================
 */

params.help = false

params.stage = ''

params.pod5 = null
params.consensus = null
params.metadata = null

params.outdir = 'results'

params.threads = 8

params.device = 'auto'


/*
 * ============================================================
 * DORADO
 * ============================================================
 */

params.dorado_model =
    'dna_r10.4.1_e8.2_400bps_sup@v5.2.0'

params.kit_name =
    'SQK-NBD114-96'


/*
 * ============================================================
 * NANOQ
 * ============================================================
 */

params.min_quality = 15
params.min_length = 800
params.max_length = 1200


/*
 * ============================================================
 * HUMAN REFERENCE
 * ============================================================
 */

params.human_ref =
    "${baseDir}/references/Human/human_g1k_v37.fasta"


/*
 * ============================================================
 * HIV REFERENCE
 * ============================================================
 */

params.hiv_ref =
    "${baseDir}/references/HIV/HXB2-pol.fasta"

params.hiv_index =
    "${baseDir}/references/HIV/HXB2-pol.mmi"


/*
 * ============================================================
 * CODFREQ
 * ============================================================
 */

params.codfreq_profile =
    "${baseDir}/references/HIV/HIV1.json"


/*
 * ============================================================
 * MEDAKA
 * ============================================================
 */

params.medaka_model =
    'r1041_e82_400bps_sup_v5.2.0'


/*
 * ============================================================
 * METADATA
 * ============================================================
 */

params.metadata_id_column =
    'sample_id'


/*
 * ============================================================
 * REPORTING
 * ============================================================
 */

params.hiv_alignment =
    "${baseDir}/references/HIV/HIV_aligned_references.fasta"


/*
 * ============================================================
 * MODULES
 * ============================================================
 */

include {
    DORADO_BASECALL
} from './modules/dorado_basecall.nf'

include {
    DORADO_DEMUX
} from './modules/dorado_demux.nf'

include {
    SANITIZEME
} from './modules/sanitizeme.nf'

include {
    NANOQ
} from './modules/nanoq.nf'

include {
    MEDAKA
} from './modules/medaka.nf'

include {
    MINIMAP2
} from './modules/minimap2.nf'

include {
    CODFREQ
} from './modules/codfreq.nf'

include {
    REPORT
} from './modules/report.nf'


/*
 * ============================================================
 * CHECKPOINT_CONSENSUS
 * ============================================================
 */

process CHECKPOINT_CONSENSUS {

    tag 'consensus-checkpoint'

    publishDir "${params.outdir}/05_consensus",
        mode: 'copy',
        overwrite: true

    input:

    path consensus_files, stageAs: 'medaka_*.fasta'

    output:

    path 'consensus.fasta',
        emit: consensus_fasta

    path 'consensus_manifest.tsv',
        emit: consensus_manifest

    path 'metadata_template.tsv',
        emit: metadata_template

    script:

    """
    set -euo pipefail

    echo ""
    echo "============================================================"
    echo " NanoHIV-DR CONSENSUS CHECKPOINT"
    echo "============================================================"
    echo ""

    rm -f consensus.fasta
    touch consensus.fasta

    echo "Collecting Medaka consensus sequences..."
    echo ""

    for f in ${consensus_files}; do

        case "\$f" in

            *.fa|*.fasta|*.fna)

                echo "Adding: \$f"
                cat "\$f" >> consensus.fasta

                ;;

            *)

                echo "Skipping non-FASTA file: \$f"

                ;;

        esac

    done


    if [[ ! -s consensus.fasta ]]; then

        echo ""
        echo "ERROR: No FASTA consensus sequences were found."
        echo ""

        ls -lah

        exit 1

    fi


    python3 - <<'PY'

from pathlib import Path

input_file = Path("consensus.fasta")
output_file = Path("consensus.normalised.fasta")

records = []

current_id = None
sequence = []


with input_file.open() as fh:

    for line in fh:

        line = line.strip()

        if not line:
            continue

        if line.startswith(">"):

            if current_id is not None:

                records.append(
                    (
                        current_id,
                        "".join(sequence)
                    )
                )

            current_id = line[1:].split()[0]
            sequence = []

        else:

            sequence.append(line)


    if current_id is not None:

        records.append(
            (
                current_id,
                "".join(sequence)
            )
        )


if not records:

    raise SystemExit(
        "ERROR: consensus.fasta contains no FASTA records."
    )


seen = set()


with output_file.open("w") as out:

    for sample_id, sequence in records:

        if not sample_id:

            raise SystemExit(
                "ERROR: Encountered an empty FASTA identifier."
            )

        if sample_id in seen:

            raise SystemExit(
                f"ERROR: Duplicate consensus identifier: {sample_id}"
            )

        if not sequence:

            raise SystemExit(
                f"ERROR: Consensus sequence is empty: {sample_id}"
            )

        seen.add(sample_id)

        out.write(f">{sample_id}" + chr(10))

        for i in range(0, len(sequence), 80):

            out.write(sequence[i:i + 80] + chr(10))


print(
    f"Found {len(records)} unique consensus sequences."
)

PY


    mv \
        consensus.normalised.fasta \
        consensus.fasta


    echo -e "sample_id\\tconsensus_file" \
        > consensus_manifest.tsv


    awk '
        /^>/ {
            id=substr($0,2)
            print id "\\tconsensus.fasta"
        }
    ' consensus.fasta \
        >> consensus_manifest.tsv


    echo -e "sample_id\\tpatient_id\\tage\\tsex\\tdate" \
        > metadata_template.tsv


    awk '
        /^>/ {
            id=substr($0,2)
            print id "\\t\\t\\t\\t"
        }
    ' consensus.fasta \
        >> metadata_template.tsv


    COUNT=\$(grep -c '^>' consensus.fasta)


    echo ""
    echo "============================================================"
    echo " CONSENSUS CHECKPOINT COMPLETE"
    echo "============================================================"
    echo ""

    echo "Consensus sequences: \$COUNT"
    echo ""

    echo "Files created:"
    echo ""
    echo "    consensus.fasta"
    echo "    consensus_manifest.tsv"
    echo "    metadata_template.tsv"
    echo ""

    echo "============================================================"
    echo " HUMAN CHECKPOINT"
    echo "============================================================"
    echo ""

    echo "Complete metadata_template.tsv."
    echo ""
    echo "DO NOT change the sample_id values."
    echo ""
    echo "Save the completed file as:"
    echo ""
    echo "    metadata.tsv"
    echo ""

    echo "Then run Stage 2:"
    echo ""

    echo "nextflow run main.nf \\\\"
    echo "    --stage report \\\\"
    echo "    --consensus ${params.outdir}/05_consensus/consensus.fasta \\\\"
    echo "    --metadata metadata.tsv \\\\"
    echo "    --outdir ${params.outdir}"

    echo ""

    echo "============================================================"
    """
}


/*
 * ============================================================
 * VALIDATE_METADATA
 * ============================================================
 */

process VALIDATE_METADATA {

    tag 'validate-metadata'

    input:

    path consensus

    path metadata

    output:

    path 'validated_metadata.tsv',
        emit: validated_metadata

    script:

    """
    set -euo pipefail

    python3 - <<'PY'

import csv


CONSENSUS = "${consensus}"
METADATA = "${metadata}"
REQUIRED_COLUMN = "${params.metadata_id_column}"


consensus_ids = []


with open(
    CONSENSUS,
    encoding="utf-8"
) as fh:

    for line in fh:

        line = line.strip()

        if not line.startswith(">"):
            continue

        sample_id = line[1:].split()[0]

        if not sample_id:

            raise SystemExit(
                "ERROR: Empty consensus FASTA identifier."
            )

        if sample_id in consensus_ids:

            raise SystemExit(
                "ERROR: Duplicate consensus identifier: "
                + sample_id
            )

        consensus_ids.append(sample_id)


if not consensus_ids:

    raise SystemExit(
        "ERROR: No consensus sequences found."
    )


consensus_set = set(consensus_ids)


with open(
    METADATA,
    newline="",
    encoding="utf-8-sig"
) as fh:

    reader = csv.DictReader(
        fh,
        delimiter="\t"
    )

    if reader.fieldnames is None:

        raise SystemExit(
            "ERROR: Metadata file is empty."
        )

    reader.fieldnames = [
        field.strip()
        for field in reader.fieldnames
    ]

    if REQUIRED_COLUMN not in reader.fieldnames:

        raise SystemExit(
            "ERROR: Metadata file must contain the "
            f"'{REQUIRED_COLUMN}' column."
        )

    rows = list(reader)


if not rows:

    raise SystemExit(
        "ERROR: Metadata file contains no data rows."
    )


metadata_ids = []
seen = set()


for row_number, row in enumerate(rows, start=2):

    sample_id = (
        row.get(
            REQUIRED_COLUMN,
            ""
        ).strip()
    )

    if not sample_id:

        raise SystemExit(
            f"ERROR: Empty {REQUIRED_COLUMN} "
            f"at metadata row {row_number}."
        )

    if sample_id in seen:

        raise SystemExit(
            f"ERROR: Duplicate {REQUIRED_COLUMN} "
            f"'{sample_id}' at metadata row "
            f"{row_number}."
        )

    seen.add(sample_id)
    metadata_ids.append(sample_id)


metadata_set = set(metadata_ids)


missing_metadata = sorted(
    consensus_set - metadata_set
)

extra_metadata = sorted(
    metadata_set - consensus_set
)


if missing_metadata or extra_metadata:

    if missing_metadata:

        print(
            "Consensus sequences missing from metadata:"
        )

        for sample_id in missing_metadata:
            print(f"    {sample_id}")


    if extra_metadata:

        print(
            "Metadata entries with no consensus sequence:"
        )

        for sample_id in extra_metadata:
            print(f"    {sample_id}")


    raise SystemExit(
        "ERROR: Consensus and metadata identifiers "
        "do not match."
    )


with open(
    METADATA,
    encoding="utf-8-sig"
) as source:

    contents = source.read()


with open(
    "validated_metadata.tsv",
    "w",
    encoding="utf-8"
) as destination:

    destination.write(contents)


print(
    f"Metadata validation passed: "
    f"{len(consensus_set)} consensus sequences."
)

PY
    """
}


/*
 * ============================================================
 * WORKFLOW
 * ============================================================
 */

workflow {


    /*
     * ========================================================
     * HELP
     * ========================================================
     */

    if (params.help) {

        log.info """

============================================================
                    NanoHIV-DR Pipeline
============================================================

STAGE 1 — CONSENSUS / ANALYSIS
============================================================

    nextflow run main.nf \\
        --stage consensus \\
        --pod5 data/pod5 \\
        --outdir results


Pipeline:

    POD5
      ↓
    Dorado
      ↓
    Demultiplex
      ↓
    SanitizeMe
      ↓
    NanoQ
      │
      ├──→ Medaka
      │      ↓
      │   Consensus
      │
      ├──→ Minimap2
      │      ↓
      │   BAM + BAI
      │
      └──→ CodFreq
             ↓
         Codon frequencies


============================================================
STAGE 2 — REPORTING
============================================================

    nextflow run main.nf \\
        --stage report \\
        --consensus results/05_consensus/consensus.fasta \\
        --metadata metadata.tsv \\
        --outdir results


============================================================

"""

        return
    }


    /*
     * ========================================================
     * VALIDATE STAGE
     * ========================================================
     */

    if (!(params.stage in ['consensus', 'report'])) {

        error """

Invalid or missing pipeline stage.

Use:

    --stage consensus

or:

    --stage report

For help:

    nextflow run main.nf --help

"""
    }


    /*
     * ========================================================
     * STAGE 1
     * ========================================================
     */

    if (params.stage == 'consensus') {


        if (!params.pod5) {

            error """

Missing required parameter:

    --pod5 <POD5_DIRECTORY>

"""
        }


        /*
         * ----------------------------------------------------
         * INPUTS
         * ----------------------------------------------------
         */

        pod5_input = channel.fromPath(
            params.pod5,
            checkIfExists: true,
            type: 'dir'
        )


        human_reference = channel.fromPath(
            params.human_ref,
            checkIfExists: true,
            type: 'file'
        )


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


        codfreq_profile = channel.fromPath(
            params.codfreq_profile,
            checkIfExists: true,
            type: 'file'
        )


        /*
         * ----------------------------------------------------
         * 1. DORADO BASECALL
         * ----------------------------------------------------
         */

        basecalled = DORADO_BASECALL(
            pod5_input
        )


        /*
         * ----------------------------------------------------
         * 2. DORADO DEMUX
         * ----------------------------------------------------
         */

        demultiplexed = DORADO_DEMUX(
            basecalled
        )


        /*
         * ----------------------------------------------------
         * 3. SANITIZEME
         * ----------------------------------------------------
         */

        host_removed = SANITIZEME(
            demultiplexed,
            human_reference
        )


        /*
         * ----------------------------------------------------
         * 4. NANOQ
         * ----------------------------------------------------
         *
         * NanoQ is the explicit branching point.
         *
         * ----------------------------------------------------
         */

        filtered = NANOQ(
            host_removed
        )


        /*
         * ====================================================
         * ARM 1 — MEDAKA
         * ====================================================
         *
         * NanoQ FASTQ
         *      ↓
         * Medaka
         *      ↓
         * consensus.fasta
         *
         * Medaka receives FASTQ directly.
         *
         * ====================================================
         */

        medaka_input = filtered
            .combine(hiv_reference)
            .map { reads, reference ->

                tuple(
                    reads,
                    reference
                )
            }


        polished = MEDAKA(
            medaka_input
        )


        /*
         * Collect only the Medaka consensus FASTA paths.
         *
		 * MEDAKA emits:
         *
 		 *     tuple(
		 *         sample_id,
		 *         consensus.fasta
		 *     )
		 *
 		 * CHECKPOINT_CONSENSUS expects only filesystem paths,
 		 * so remove the sample_id value before collecting.
 		 */

		consensus_files = polished
			.map { sample_id, consensus_fasta ->
				consensus_fasta
			}
			.collect()
			
			/*
 			 * Human checkpoint.
 			 */
 			 
 			CHECKPOINT_CONSENSUS(
 				consensus_files
 			)

        /*
         * ====================================================
         * ARM 2 — MINIMAP2
         * ====================================================
         *
         * NanoQ FASTQ
         *      ↓
         * Minimap2
         *      ↓
         * BAM + BAI
         *
         * IMPORTANT:
         *
         * MINIMAP2 is called ONLY ONCE.
         *
         * ====================================================
         */

        minimap_inputs = filtered
            .combine(hiv_index)
            .map { reads, index ->

                tuple(
                    index,
                    reads
                )
            }


        alignment = MINIMAP2(
            minimap_inputs
        )


        /*
         * ====================================================
         * ARM 3 — CODFREQ
         * ====================================================
         *
         * CodFreq is intentionally fed from the NanoQ FASTQ
         * channel rather than from the Minimap2 BAM channel.
         *
         * The CODFREQ module should therefore accept:
         *
         *     tuple path(reads), path(profile)
         *
         * and invoke fastq2codfreq.
         *
         * ====================================================
         */

        codfreq_inputs = filtered
            .combine(codfreq_profile)
            .map { reads, profile ->

                tuple(
                    reads,
                    profile
                )
            }


        codfreq_results = CODFREQ(
            codfreq_inputs
        )


        /*
         * Display CodFreq outputs without making them a
         * dependency of the consensus or Minimap2 arms.
         */

        codfreq_results.view {
            "CodFreq result: ${it}"
        }

    }


    /*
     * ========================================================
     * STAGE 2 — REPORT
     * ========================================================
     */

    if (params.stage == 'report') {


        if (!params.consensus) {

            error """

Missing required parameter:

    --consensus <CONSENSUS_FASTA>

"""
        }


        if (!params.metadata) {

            error """

Missing required parameter:

    --metadata <METADATA_TSV>

"""
        }


        consensus_input = channel.fromPath(
            params.consensus,
            checkIfExists: true,
            type: 'file'
        )


        metadata_input = channel.fromPath(
            params.metadata,
            checkIfExists: true,
            type: 'file'
        )


        validated_metadata = VALIDATE_METADATA(
            consensus_input,
            metadata_input
        )


        REPORT(
            consensus_input,
            validated_metadata
        )

    }


    /*
     * ========================================================
     * COMPLETION SUMMARY
     * ========================================================
     */

    workflow.onComplete { wf ->

        def status = wf.success
            ? 'SUCCESS'
            : 'FAILED'


        println ""

        println "============================================================"
        println " NanoHIV-DR WORKFLOW COMPLETE"
        println "============================================================"

        println ""

        println "Status:"
        println "    ${status}"

        println ""

        println "Duration:"
        println "    ${workflow.duration}"

        println ""

        println "Output directory:"
        println "    ${params.outdir}"

        println ""


        if (params.stage == 'consensus') {

            println "Stage 1 outputs:"
            println ""

            println "    ${params.outdir}/01_basecalled/"
            println "    ${params.outdir}/02_demultiplexed/"
            println "    ${params.outdir}/03_removehost/"
            println "    ${params.outdir}/04_nanoq/"
            println "    ${params.outdir}/05_consensus/"
            println "    ${params.outdir}/06_minimap2/"
            println "    ${params.outdir}/08_codfreq/"

            println ""

            println "Human checkpoint:"
            println ""

            println "    ${params.outdir}/05_consensus/metadata_template.tsv"

            println ""

            println "Complete metadata_template.tsv."
            println "Do not change sample_id values."

            println ""

            println "Save as:"
            println ""

            println "    metadata.tsv"

            println ""

            println "Then run Stage 2:"
            println ""

            println "    nextflow run main.nf \\"
            println "        --stage report \\"
            println "        --consensus ${params.outdir}/05_consensus/consensus.fasta \\"
            println "        --metadata metadata.tsv \\"
            println "        --outdir ${params.outdir}"

        }


        if (params.stage == 'report') {

            if (workflow.success) {

                println ""
                println "Clinical reporting completed successfully."
                println ""

            }

        }


        println ""
        println "============================================================"
        println ""

    }

}
