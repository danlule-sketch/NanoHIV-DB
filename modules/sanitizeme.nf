process SANITIZEME {

	tag "${reads.simpleName}"

	cpus 8

	publishDir "${params.outdir}/03_removehost", mode: 'copy'

	input:
	path reads

	output:
	path "${reads.simpleName}_filtered.fastq"

	script:
	"""
	sanitizeme \
    	--input ${reads} \
    	--output ${reads.simpleName}_filtered.fastq
	"""

}
