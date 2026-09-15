#!/usr/bin/env nextflow

/*
 * ============================================================
 * NanoHIV-DR
 * ============================================================
 *
 * Two-stage Oxford Nanopore HIV drug-resistance workflow.
 *
 *
 * STAGE 1 — CONSENSUS
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
 *   ↓
 * Minimap2
 *   ↓
 * ┌─────────────────────┬─────────────────────┐
 * ↓                     ↓
 * Medaka                CodFreq
 * ↓                     ↓
 * Consensus             Variant results
 * ↓
 * Human checkpoint
 *
 *
 * STAGE 2 — REPORTING
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
 * Pipeline parameters
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

params.dorado_model =
    'dna_r10.4.1_e8.2_400bps_sup@v5.2.0'

params.kit_name =
    'SQK-NBD114-96'

params.min_quality = 15
params.min_length = 800
params.max_length = 1200

params.hiv_ref =
    "${baseDir}/references/HIV/HXB2-pol.fasta"

params.hiv_index =
    "${baseDir}/references/HIV/HXB2-pol.mmi"

params.medaka_model =
    'r1041_e82_400bps_sup_v5.2.0'

params.metadata_id_column =
    'sample_id'


/*
 * ============================================================
 * Modules
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
    MINIMAP2
} from './modules/minimap2.nf'

include {
    MEDAKA
} from './modules/medaka.nf'

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
 *
 * Collects all Medaka consensus FASTA files.
 *
 * Produces:
 *
 *     consensus.fasta
 *     consensus_manifest.tsv
 *     metadata_template.tsv
 *
 * This is the deliberate human checkpoint between Stage 1
 * and Stage 2.
 * ============================================================
 */

process CHECKPOINT_CONSENSUS {

    tag 'consensus-checkpoint'

    publishDir "${params.outdir}/consensus",
        mode: 'copy',
        overwrite: true

    input:

    path consensus_files


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

    echo "Collecting Medaka consensus sequences..."
    echo ""

    rm -f consensus.fasta
    touch consensus.fasta


    # ----------------------------------------------------------
    # Collect FASTA files
    # ----------------------------------------------------------

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


    # ----------------------------------------------------------
    # Confirm that consensus sequences were produced
    # ----------------------------------------------------------

    if [[ ! -s consensus.fasta ]]; then

        echo ""
        echo "ERROR: No FASTA consensus sequences were found."
        echo ""
        echo "Files received:"
        ls -lh
        echo ""

        exit 1

    fi


    # ----------------------------------------------------------
    # Normalise FASTA identifiers
    # ----------------------------------------------------------

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


        out.write(f">{sample_id}\\n")


        for i in range(0, len(sequence), 80):

            out.write(sequence[i:i + 80] + "\\n")


print(
    f"Found {len(records)} unique consensus sequences."
)

PY


    mv consensus.normalised.fasta consensus.fasta


    # ----------------------------------------------------------
    # Create consensus manifest
    # ----------------------------------------------------------

    echo -e "sample_id\\tconsensus_file" \
        > consensus_manifest.tsv


    awk '
        /^>/ {
            id=substr($0,2)
            print id "\\tconsensus.fasta"
        }
    ' consensus.fasta \
        >> consensus_manifest.tsv


    # ----------------------------------------------------------
    # Create metadata template
    # ----------------------------------------------------------

    echo -e "sample_id\\tpatient_id\\tage\\tsex\\tdate" \
        > metadata_template.tsv


    awk '
        /^>/ {
            id=substr($0,2)
            print id "\\t\\t\\t\\t"
        }
    ' consensus.fasta \
        >> metadata_template.tsv


    # ----------------------------------------------------------
    # Summary
    # ----------------------------------------------------------

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

    echo "Complete:"
    echo ""
    echo "    metadata_template.tsv"
    echo ""

    echo "IMPORTANT:"
    echo ""
    echo "DO NOT change the sample_id values."
    echo ""

    echo "Save the completed metadata file as:"
    echo ""
    echo "    metadata.tsv"
    echo ""

    echo "Then run Stage 2:"
    echo ""

    echo "nextflow run main.nf \\\\"
    echo "    --stage report \\\\"
    echo "    --consensus ${params.outdir}/consensus/consensus.fasta \\\\"
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
 *
 * Validates:
 *
 *   1. Consensus FASTA exists.
 *   2. Consensus identifiers are unique.
 *   3. Metadata contains the required identifier column.
 *   4. Metadata contains data rows.
 *   5. Metadata identifiers are not empty.
 *   6. Metadata identifiers are unique.
 *   7. Every consensus has exactly one metadata row.
 *   8. No metadata row exists without a consensus.
 *
 * Produces:
 *
 *     validated_metadata.tsv
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


print("")
print("============================================================")
print(" VALIDATING METADATA")
print("============================================================")
print("")


# ------------------------------------------------------------
# Read consensus identifiers
# ------------------------------------------------------------

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


# ------------------------------------------------------------
# Read metadata
# ------------------------------------------------------------

with open(
    METADATA,
    newline="",
    encoding="utf-8-sig"
) as fh:

    reader = csv.DictReader(
        fh,
        delimiter="\\t"
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
            f"'{REQUIRED_COLUMN}' column.\\n"
            f"Columns found: {reader.fieldnames}"
        )


    rows = list(reader)


if not rows:

    raise SystemExit(
        "ERROR: Metadata file contains no data rows."
    )


# ------------------------------------------------------------
# Validate metadata identifiers
# ------------------------------------------------------------

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


# ------------------------------------------------------------
# Compare identifiers
# ------------------------------------------------------------

missing_metadata = sorted(
    consensus_set - metadata_set
)


extra_metadata = sorted(
    metadata_set - consensus_set
)


if missing_metadata or extra_metadata:

    print("")
    print("============================================================")
    print(" METADATA VALIDATION FAILED")
    print("============================================================")
    print("")


    if missing_metadata:

        print(
            "Consensus sequences missing from metadata:"
        )

        for sample_id in missing_metadata:

            print(
                f"    {sample_id}"
            )

        print("")


    if extra_metadata:

        print(
            "Metadata entries with no consensus sequence:"
        )

        for sample_id in extra_metadata:

            print(
                f"    {sample_id}"
            )

        print("")


    print(
        f"Consensus sequences: {len(consensus_set)}"
    )

    print(
        f"Metadata entries:    {len(metadata_set)}"
    )

    print("")


    raise SystemExit(
        "ERROR: Consensus and metadata identifiers "
        "do not match."
    )


# ------------------------------------------------------------
# Write validated metadata
# ------------------------------------------------------------

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


print("")
print("============================================================")
print(" METADATA VALIDATION PASSED")
print("============================================================")
print("")

print(
    f"Consensus sequences: {len(consensus_set)}"
)

print(
    f"Metadata entries:    {len(metadata_set)}"
)

print("")

print(
    "Every consensus sequence has exactly one "
    "metadata row."
)

print("")

print(
    "Proceeding to clinical reporting."
)

print("")

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

Two-stage HIV drug-resistance workflow for Oxford Nanopore
sequencing data.


============================================================
STAGE 1 — CONSENSUS
============================================================

Run:

    nextflow run main.nf \\
        --stage consensus \\
        --pod5 data/pod5 \\
        --outdir results


CPU:

    nextflow run main.nf \\
        --stage consensus \\
        --pod5 data/pod5 \\
        --outdir results \\
        --device cpu


Produces:

    results/consensus/consensus.fasta

    results/consensus/consensus_manifest.tsv

    results/consensus/metadata_template.tsv


Complete metadata_template.tsv without changing the
sample_id values.

Save the completed file as:

    metadata.tsv


============================================================
STAGE 2 — REPORTING
============================================================

Run:

    nextflow run main.nf \\
        --stage report \\
        --consensus results/consensus/consensus.fasta \\
        --metadata metadata.tsv \\
        --outdir results


============================================================
GENERAL PARAMETERS
============================================================

--outdir <DIRECTORY>

    Output directory.

    Default:
        results


--threads <INTEGER>

    Number of threads.

    Default:
        8


--device <DEVICE>

    Dorado compute device.

    Default:
        auto

    Examples:
        auto
        cpu
        cuda:all
        cuda:0


============================================================
DORADO
============================================================

--dorado_model <MODEL>

    Default:
        dna_r10.4.1_e8.2_400bps_sup@v5.2.0


--kit_name <KIT>

    Default:
        SQK-NBD114-96


============================================================
NANOQ
============================================================

--min_quality <INTEGER>

    Default:
        15


--min_length <INTEGER>

    Default:
        800


--max_length <INTEGER>

    Default:
        1200


============================================================
HIV REFERENCE
============================================================

--hiv_ref <FASTA>

    Default:
        references/HIV/HXB2-pol.fasta


--hiv_index <MMI>

    Default:
        references/HIV/HXB2-pol.mmi


============================================================
MEDAKA
============================================================

--medaka_model <MODEL>

    Default:
        r1041_e82_400bps_sup_v5.2.0


============================================================
METADATA
============================================================

--metadata_id_column <COLUMN>

    Default:
        sample_id


============================================================
RESUME
============================================================

    nextflow run main.nf -resume \\
        --stage consensus \\
        --pod5 data/pod5 \\
        --outdir results


============================================================

"""

        return
    }


    /*
     * ========================================================
     * Validate stage
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
     * STAGE 1 — CONSENSUS
     * ========================================================
     */

    if (params.stage == 'consensus') {


        /*
         * ----------------------------------------------------
         * Validate POD5 parameter
         * ----------------------------------------------------
         */

        if (!params.pod5) {

            error """

Missing required parameter:

    --pod5 <POD5_DIRECTORY>

Example:

    nextflow run main.nf \\
        --stage consensus \\
        --pod5 data/pod5

"""
        }


        /*
         * ----------------------------------------------------
         * POD5 input
         * ----------------------------------------------------
         */

        pod5_input = channel.fromPath(
            params.pod5,
            checkIfExists: true,
            type: 'dir'
        )


        /*
         * ----------------------------------------------------
         * HIV reference
         * ----------------------------------------------------
         */

        hiv_reference = channel.fromPath(
            params.hiv_ref,
            checkIfExists: true,
            type: 'file'
        )


        /*
         * ----------------------------------------------------
         * HIV minimap2 index
         * ----------------------------------------------------
         */

        hiv_index = channel.fromPath(
            params.hiv_index,
            checkIfExists: true,
            type: 'file'
        )


        /*
         * ----------------------------------------------------
         * 1. Dorado basecalling
         * ----------------------------------------------------
         */

        basecalled = DORADO_BASECALL(
            pod5_input
        )


        /*
         * ----------------------------------------------------
         * 2. Dorado demultiplexing
         * ----------------------------------------------------
         */

        demultiplexed = DORADO_DEMUX(
            basecalled
        )


        /*
         * ----------------------------------------------------
         * 3. SanitizeMe
         * ----------------------------------------------------
         */

        host_removed = SANITIZEME(
            demultiplexed
        )


        /*
         * ----------------------------------------------------
         * 4. NanoQ
         * ----------------------------------------------------
         */

        filtered = NANOQ(
            host_removed
        )


        /*
         * ----------------------------------------------------
         * 5. Minimap2
         *
         * Expected input:
         *
         *     tuple(index, reads)
         * ----------------------------------------------------
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
         * ----------------------------------------------------
         * Extract BAM from Minimap2 output.
         *
         * Expected MINIMAP2 output:
         *
         *     BAM
         *     BAI
         * ----------------------------------------------------
         */

        bam = alignment.map {

            bam_file,
            bai_file ->

                bam_file

        }


        /*
         * ----------------------------------------------------
         * Combine BAM with reference.
         *
         * Used by:
         *
         *     MEDAKA
         *     CODFREQ
         * ----------------------------------------------------
         */

        bam_reference = bam
            .combine(hiv_reference)
            .map { bam_file, reference ->

                tuple(
                    bam_file,
                    reference
                )

            }


        /*
         * ----------------------------------------------------
         * 6. Medaka
         * ----------------------------------------------------
         */

        polished = MEDAKA(
            bam_reference
        )


        /*
         * ----------------------------------------------------
         * 7. CodFreq
         * ----------------------------------------------------
         */

        codfreq_results = CODFREQ(
            bam_reference
        )


        /*
         * ----------------------------------------------------
         * 8. Collect Medaka consensus files
         * ----------------------------------------------------
         */

        consensus_files = polished.collect()


        /*
         * ----------------------------------------------------
         * 9. Human checkpoint
         * ----------------------------------------------------
         */

        CHECKPOINT_CONSENSUS(
            consensus_files
        )

    }


    /*
     * ========================================================
     * STAGE 2 — REPORT
     * ========================================================
     */

    if (params.stage == 'report') {


        /*
         * ----------------------------------------------------
         * Validate consensus parameter
         * ----------------------------------------------------
         */

        if (!params.consensus) {

            error """

Missing required parameter:

    --consensus <CONSENSUS_FASTA>

Example:

    nextflow run main.nf \\
        --stage report \\
        --consensus results/consensus/consensus.fasta \\
        --metadata metadata.tsv

"""
        }


        /*
         * ----------------------------------------------------
         * Validate metadata parameter
         * ----------------------------------------------------
         */

        if (!params.metadata) {

            error """

Missing required parameter:

    --metadata <METADATA_TSV>

Example:

    nextflow run main.nf \\
        --stage report \\
        --consensus results/consensus/consensus.fasta \\
        --metadata metadata.tsv

"""
        }


        /*
         * ----------------------------------------------------
         * Consensus FASTA
         * ----------------------------------------------------
         */

        consensus_input = channel.fromPath(
            params.consensus,
            checkIfExists: true,
            type: 'file'
        )


        /*
         * ----------------------------------------------------
         * Metadata TSV
         * ----------------------------------------------------
         */

        metadata_input = channel.fromPath(
            params.metadata,
            checkIfExists: true,
            type: 'file'
        )


        /*
         * ----------------------------------------------------
         * Validate metadata
         * ----------------------------------------------------
         */

        validated_metadata = VALIDATE_METADATA(
            consensus_input,
            metadata_input
        )


        /*
         * ----------------------------------------------------
         * Clinical reporting
         * ----------------------------------------------------
         */

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

    workflow.onComplete = {

        def status = workflow.success
            ? 'SUCCESS'
            : 'FAILED'


        println ""

        println "============================================================"
        println " NanoHIV-DR WORKFLOW COMPLETE"
        println "============================================================"
        println ""

        println "Status:"
        println ""
        println "    ${status}"

        println ""

        println "Duration:"
        println ""
        println "    ${workflow.duration}"

        println ""

        println "Completed:"
        println ""
        println "    ${workflow.complete}"

        println ""

        println "Output directory:"
        println ""
        println "    ${params.outdir}"

        println ""


        if (workflow.success) {


            if (params.stage == 'consensus') {

                println "Stage 1 outputs:"
                println ""

                println "    ${params.outdir}/consensus/consensus.fasta"

                println "    ${params.outdir}/consensus/consensus_manifest.tsv"

                println "    ${params.outdir}/consensus/metadata_template.tsv"

                println ""

                println "Human checkpoint:"
                println ""

                println "    Complete metadata_template.tsv"
                println "    without changing sample_id values."

                println ""

                println "    Save the completed file as:"
                println ""
                println "        metadata.tsv"

                println ""

                println "Then run Stage 2:"
                println ""

                println "    nextflow run main.nf \\\\"
                println "        --stage report \\\\"
                println "        --consensus ${params.outdir}/consensus/consensus.fasta \\\\"
                println "        --metadata metadata.tsv \\\\"
                println "        --outdir ${params.outdir}"

            }


            if (params.stage == 'report') {

                println "Clinical reporting completed successfully."

            }

        }
        else {

            println "The workflow did not complete successfully."

            println ""

            if (workflow.errorMessage) {

                println "Error:"
                println ""

                println "    ${workflow.errorMessage}"

            }

        }


        println ""

        println "============================================================"
        println ""

    }

}
