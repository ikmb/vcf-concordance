# Usage information

## Basic execution

This pipeline requires Nextflow and Singularity to be loaded/available. 

To run the pipeline on the IKMB MedCluster, the following command should work:

```bash
nextflow run ikmb/vcf-concordance --vcf your_variants.vcf.gz --reference NA12878 --assembly hg38
```

The options are described in the following:

## Options

### `--ref_version`
Release version of GIAB to use (v3, v4 (default)). Note that 4.2.1 uses patch 14 of GRCh38; whereas 3.3.1 is based on an older version. 

### `--vcf`
A gzipped, indexed (!) VCF file to be benchmarked. 

### `--reference`
The ID of a Genome-in-a-Bottle reference. Valid options are:

- NA12878
- NA24143
- NA24149
- NA24385
- NA24631
- NA24694
- NA24695

### `--bed`
A Bed file of e.g. your captured targets (exomes, panels). If you do not want to limit the analysis to any particular region(s), just leave this option empty. 

### `--assembly`
The human genome build to use. The default option is hg38 - other options are not currently configured. 

## Expert options

### `--ref_vcf`
A gzipped, indexed VCF file to benchmark against (usually a Genome-in-a-Bottle sample)


### `--ref_bed`
A bed file with high-confidence calling intervals in your reference (included with every GIAB data set)

