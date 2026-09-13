process NANOQ {

tag "${reads.simpleName}"

publishDir "${params.outdir}/04_filtered",
    mode: 'copy',
    overwrite: true

input:
path reads

output:
path "${reads.simpleName}.trimmed.fastq",
    emit: filtered_reads

script:
"""
set -euo pipefail

echo "============================================================"
echo " NanoQ"
echo "============================================================"
echo "Input:       ${reads}"
echo "Min quality: ${params.min_quality}"
echo "Min length:  ${params.min_length}"
echo "Max length:  ${params.max_length}"
echo ""

nanoq \
    ${reads} \
    -q ${params.min_quality} \
    -l ${params.min_length} \
    -m ${params.max_length} \
    > ${reads.simpleName}.trimmed.fastq

if [[ ! -s ${reads.simpleName}.trimmed.fastq ]]; then
    echo "ERROR: NanoQ produced an empty output file."
    exit 1
fi

echo ""
echo "NanoQ filtering complete."
echo "Output: ${reads.simpleName}.trimmed.fastq"
"""

}