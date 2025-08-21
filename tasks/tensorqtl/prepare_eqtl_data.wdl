# MIT License
#
# Copyright 2025 Broad Institute
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

version 1.0

task prepare_eqtl_data {
    input {
        # required inputs
        File metacells
        File annotations
        File sequence_dictionary
        File vcf
        File vcf_idx
        File donor_covariates

        # optional inputs
        File? rejected_donor_list
        File? interval_file
        Int transcripts_per_cell = -1 # do not normalize expression
        Float? remove_pct_expression
        Int? gq_threshold
        Float? fraction_samples_passing
        Float? hwe_pvalue
        Float? maf
        Array[String] ignored_chromosomes = []
        Array[String] prepare_eqtl_data_args = []
        String covariate_validation = "STRICT" # Ensure that all covariates are numeric
        String validation_stringency = "SILENT"

        # optional outputs
        String? genotype_bed_path
        String? gene_expression_path
        String? covariates_path
        String? donor_list_path

        # runtime values
        String docker = "quay.io/broadinstitute/drop-seq_java:current"
        Int cpu = 2
        Int memory_mb = 16384
        Int disk_gb = 20
        Int preemptible = 2
    }

    parameter_meta {
        vcf: {
            localization_optional: true
        }
        vcf_idx: {
            localization_optional: true
        }
    }

    Array[String] ignored_chromosomes_list = if (length(ignored_chromosomes) > 0) then flatten([["null"], ignored_chromosomes]) else []

    # Java doesn't produce the same gzipped output as gzip, use re_gz to ensure serial and parallel match.
    # h/t for prefix workaround: https://github.com/broadinstitute/cromwell/issues/5092#issuecomment-515872319
    command <<<
        set -euo pipefail

        mem_unit=$(echo "${MEM_UNIT:-}" | cut -c 1)
        if [[ $mem_unit == "M" ]]; then
            mem_size=$(awk "BEGIN {print int($MEM_SIZE)}")
        elif [[ $mem_unit == "G" ]]; then
            mem_size=$(awk "BEGIN {print int($MEM_SIZE * 1024)}")
        else
            mem_size=$(free -m | awk '/^Mem/ {print $2}')
        fi
        mem_size=$(awk "BEGIN {print int($mem_size * 7 / 8)}")

        PrepareEqtlData \
            -m ${mem_size}m \
            --META_CELL_FILE ~{metacells} \
            --ANNOTATIONS_FILE ~{annotations} \
            --SEQUENCE_DICTIONARY ~{sequence_dictionary} \
            --INPUT_VCF ~{vcf} \
            --COVARIATE_FILE ~{donor_covariates} \
            ~{if defined(interval_file) then "--INTERVAL_FILE " + interval_file else "" } \
            ~{if defined(rejected_donor_list) then "--REJECTED_DONOR_LIST " + rejected_donor_list else ""} \
            --TRANSCRIPTS_PER_CELL ~{transcripts_per_cell} \
            ~{if defined(remove_pct_expression) then "--REMOVE_PCT_EXPRESSION " + remove_pct_expression else ""} \
            ~{if defined(gq_threshold) then "--GQ_THRESHOLD " + gq_threshold else ""} \
            ~{if defined(fraction_samples_passing) then "--FRACTION_SAMPLES_PASSING " + fraction_samples_passing else ""} \
            ~{if defined(hwe_pvalue) then "--HWE_PVALUE " + hwe_pvalue else ""} \
            ~{if defined(maf) then "--MAF " + maf else ""} \
            ~{true="--IGNORED_CHROMOSOMES " false="" length(ignored_chromosomes_list) > 0}~{sep=" --IGNORED_CHROMOSOMES " ignored_chromosomes_list} \
            ~{sep=" " prepare_eqtl_data_args} \
            ~{if defined(genotype_bed_path) then "--GENOTYPE_BED " + genotype_bed_path else ""} \
            ~{if defined(gene_expression_path) then "--EXPRESSION_BED_FILE " + gene_expression_path else ""} \
            ~{if defined(covariates_path) then "--COVARIATE_MATRIX " + covariates_path else ""} \
            ~{if defined(donor_list_path) then "--OUT_DONOR_LIST " + donor_list_path else ""} \
            --COVARIATE_VALIDATION ~{covariate_validation} \
            --VALIDATION_STRINGENCY ~{validation_stringency}

        re_gz() {
            local gz_file=$1
            local tmp_file=$gz_file.tmp
            if [[ $gz_file != *.gz ]]; then return; fi
            mv "$gz_file" "$tmp_file"
            gunzip -c "$tmp_file" | gzip -n > "$gz_file"
        }

        re_gz ~{genotype_bed_path}
    >>>

    runtime {
        docker: docker
        cpu: cpu
        memory: memory_mb + " MB"
        disks: "local-disk " + disk_gb + " HDD"
        preemptible: preemptible
    }

    output {
        File? genotype_bed = genotype_bed_path
        File? donor_list = donor_list_path
        File? gene_expression = gene_expression_path
        File? covariates = covariates_path
    }
}
