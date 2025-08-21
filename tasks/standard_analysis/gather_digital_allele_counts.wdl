# MIT License
#
# Copyright 2024 Broad Institute
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

task gather_digital_allele_counts {
    input {
        # required inputs
        File alignment_bam
        File vcf
        File vcf_idx
        File selected_cell_barcodes
        File sample_file
        Boolean single_variant_reads
        Boolean multi_genes_per_read

        # optional inputs
        String? cell_barcode_tag # CB
        String? molecular_barcode_tag # UB
        Array[String] ignored_chromosomes = []
        Array[String] locus_function_list = []
        String? strand_strategy
        String validation_stringency = "SILENT"

        # required outputs
        String allele_frequency_output_path

        # runtime values
        String docker = "quay.io/broadinstitute/drop-seq_java:current"
        Int cpu = 2
        Int memory_mb = 32768
        Int disk_gb = 10
        Int preemptible = 2
    }

    parameter_meta {
        alignment_bam: {
            localization_optional: true
        }
        vcf: {
            localization_optional: true
        }
        vcf_idx: {
            localization_optional: true
        }
    }

    # Since GatherDigitalAlleleCounts does not default its IGNORED_CHROMOSOMES, it triggers a bug in Barclay where we
    # cannot pass in "null" to reset the list. If/when the issue is fixed this code can match the other WDLs.
    #  - https://github.com/broadinstitute/Drop-seq/blob/23712bc/src/java/org/broadinstitute/dropseqrna/barnyard/digitalallelecounts/GatherDigitalAlleleCounts.java#L123
    #  - https://github.com/broadinstitute/barclay/issues/201
    # Array[String] ignored_chromosomes_list = if (length(ignored_chromosomes) > 0) then flatten([["null"], ignored_chromosomes]) else []
    Array[String] ignored_chromosomes_list = ignored_chromosomes

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

        GatherDigitalAlleleCounts \
            -m ${mem_size}m \
            --INPUT ~{alignment_bam} \
            --VCF ~{vcf} \
            --CELL_BC_FILE ~{selected_cell_barcodes} \
            --SAMPLE_FILE ~{sample_file} \
            --SINGLE_VARIANT_READS ~{single_variant_reads} \
            --MULTI_GENES_PER_READ ~{multi_genes_per_read} \
            ~{if defined(cell_barcode_tag) then "--CELL_BARCODE_TAG " + cell_barcode_tag else ""} \
            ~{if defined(molecular_barcode_tag) then "--MOLECULAR_BARCODE_TAG " + molecular_barcode_tag else ""} \
            ~{true="--IGNORED_CHROMOSOMES " false="" length(ignored_chromosomes_list) > 0}~{sep=" --IGNORED_CHROMOSOMES " ignored_chromosomes_list} \
            ~{true="--LOCUS_FUNCTION_LIST " false="" length(locus_function_list) > 0}~{sep=" --LOCUS_FUNCTION_LIST " locus_function_list} \
            ~{if defined(strand_strategy) then "--STRAND_STRATEGY " + strand_strategy else ""} \
            --ALLELE_FREQUENCY_OUTPUT ~{allele_frequency_output_path} \
            --VALIDATION_STRINGENCY ~{validation_stringency}
    >>>

    runtime {
        docker: docker
        cpu: cpu
        memory: memory_mb + " MB"
        disks: "local-disk " + disk_gb + " HDD"
        preemptible: preemptible
    }

    output {
        File allele_frequency_output = allele_frequency_output_path
    }
}
