#!/usr/bin/env nextflow

/**
===============================
Pipeline
===============================

This Pipeline performs ....

### Homepage / git
git@github.com:ikmb/pipeline.git

**/

// Pipeline version

params.pipe_version = workflow.manifest.version

// Help message
helpMessage = """
===============================================================================
IKMB variant concordance pipeline | version ${params.pipe_version}
===============================================================================
Usage: nextflow run ikmb/vcf-concordance

Required parameters:
--email 		       Email address to send reports to (enclosed in '')
--vcf				A vcf file of regular expression of multiple VCF files
--assembly			Version of the human genome to use (default: hg38)
--reference			ID of the Genome-in-a-bottle reference to compare against
Optional parameters:
--bed                           BED file with calling intervals to compare against. This would be your exome capture kit. Leave empty if analyzing WGS data. 
--ref_vcf			Path to an alternative reference VCF (instead of --reference)
--ref_bed			Path to an alterantive reference (high-confidence) BED file (instead of --reference)

Expert options (usually not necessary to change!):

Output:
--outdir                       Local directory to which all output is written (default: results)
"""

params.help = false

// Show help when needed
if (params.help){
    log.info helpMessage
    exit 0
}

if (!params.genomes[params.ref_version].containsKey(params.assembly)) {
	exit 1, "This assembly does not seem to be defined..."
}
if(!params.ref_vcf && !params.reference) {
	exit 1, "Must specifiy an existing reference or provide a reference in VCF format"
} else if (params.reference && !params.genomes[params.ref_version][ params.assembly ].containsKey(params.reference)) {
	exit 1, "This reference does not seem to be defined for this assembly yet..."
}
//A custom reference is given - how do we determine regions of interest
if (params.ref_vcf) {
	if (params.ref_bed) {
		ref_bed = params.ref_bed
	} else if (params.bed) {
		ref_bed = params.bed
	}
} 
// We have a reference specified
if (params.reference) {
	giab_vcf = file(params.genomes[params.ref_version][ params.assembly ][params.reference].vcf, checkIfExists: true)
	giab_bed = file(params.genomes[params.ref_version][ params.assembly ][params.reference].bed, checkIfExists: true)
        log.info "Using ${params.genomes[params.ref_version][ params.assembly ][params.reference].vcf} as reference"
// Instead, a reference is provided manually
} else if (params.ref_vcf) {
	giab_vcf = file(params.ref_vcf)
	giab_bed = file(ref_bed)
} else {
	exit 1, "Missing a reference to compare against!"
}

fasta = file(params.genomes[params.ref_version][ params.assembly ].fasta, checkIfExists: true)

// Channels
Channel.fromPath(giab_bed)
	.ifEmpty { exit 1; "Could not find the reference BED file (via --reference or --ref_bed)" }
	.set { bed_giab }

Channel.fromPath(giab_vcf)
	.ifEmpty { exit 1, "Could not find the reference VCF file (via --reference or --ref_vcf)" }
	.map { v -> [ file(v), file("${v}.tbi", checkIfExists: true)] }
	.set { vcf_giab }

Channel.fromPath(params.vcf)
	.ifEmpty { exit 1, "Could not find the VCF file(s) (--vcf)" }
        .map { v -> [ file(v), file("${v}.tbi", checkIfExists: true)] }
	.set { vcf_file }

def summary = [:]

run_name = ( params.run_name == false) ? "${workflow.sessionId}" : "${params.run_name}"

log.info "VCF Concordance Check Pipeline thingy | ${workflow.manifest.version}"
log.info "--------------------------------------------------------------------"
log.info "Assembly:     ${params.assembly}"
if (params.reference) {
        log.info "Reference:    ${params.reference}"
}
if (params.bed) {
        log.info "BED file:     ${params.bed}"
}
log.info "Input(s):     ${params.vcf}"
log.info "--------------------------------------------------------------------"

// User-provided provided bed if working with exome data
if (params.bed) {

	bed_kit = Channel.fromPath(params.bed)

	process bed_intersect {

		label 'bedtools'

		input:
		path(bed_k) from bed_kit
		path(bed_g) from bed_giab

		output:
		path(bed) into bed_file
	
		script:

		bed = "calling_regions.bed"

		"""
			bedtools intersect -a $bed_g -b $bed_k > $bed
		"""
	}

} else {
	bed_file = Channel.fromPath(giab_bed)
}

process normalize {

	label 'gatk'

	input:
	tuple path(vcf),path(tbi) from vcf_file

	output:
	tuple path(vcf_normalized),path(vcf_normalized_tbi) into input_happy

	script:
	vcf_normalized = vcf.getBaseName() + ".normalized.vcf.gz"
	vcf_normalized_tbi = vcf_normalized + ".tbi"

	"""
		gatk SelectVariants -R $fasta --exclude-filtered --exclude-non-variants --remove-unused-alternates -V $vcf -OVI -O tmp.vcf.gz 
		gatk LeftAlignAndTrimVariants -R $fasta -V tmp.vcf.gz -O $vcf_normalized -OVI
		rm tmp.vcf.gz
	"""
}

process happy {

	label 'happy'

	publishDir "${params.outdir}/Happy", mode: 'copy'

	input:
	tuple path(vcf_r),path(vcf_r_tbi) from vcf_giab.collect()
	tuple path(vcf),path(vcf_tbi) from input_happy
	path(bed) from bed_file.collect()

	output:
	path(summary_csv)

	script:
	base = vcf.getBaseName()
	summary_csv = base + ".summary.csv"

	"""
		hap.py $vcf_r $vcf -T $bed -o $base -r $fasta
		sed -i.bak 's/,/	/g' $summary_csv
	"""

}
	
