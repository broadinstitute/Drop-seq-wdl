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

task assign_cells_to_samples {
    input {
        # required inputs
        File input_bam
        File vcf
        File vcf_idx
        File cell_bc_file

        # optional inputs
        String? cell_barcode_tag # CB
        String? molecular_barcode_tag # UB
        String? function_tag # XF
        Int? edit_distance
        Array[String] ignored_chromosomes = []
        Array[String] locus_function_list = []
        String? strand_strategy
        File? cell_contamination_estimate_file
        File? allele_frequency_estimate_file
        String additional_options = ""
        String validation_stringency = "SILENT"

        # required outputs
        String vcf_output_path
        String output_file_path

        # runtime values
        String docker = "quay.io/broadinstitute/drop-seq_java:current"
        Int cpu = 2
        Int memory_mb = 32768
        Int disk_gb = 10 + (2 * ceil(size(vcf, "GB")))
        Int preemptible = 2
    }

    parameter_meta {
        input_bam: {
            localization_optional: true
        }
        vcf: {
            localization_optional: true
        }
        vcf_idx: {
            localization_optional: true
        }
    }

    Array[String] ignored_chromosomes_list = if (length(ignored_chromosomes) > 0) then flatten([["null"], ignored_chromosomes]) else []
    Boolean do_cell_contamination_estimate_file = defined(cell_contamination_estimate_file) && defined(allele_frequency_estimate_file)

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

        AssignCellsToSamples \
            -m ${mem_size}m \
            --INPUT_BAM ~{input_bam} \
            --VCF ~{vcf} \
            --CELL_BC_FILE ~{cell_bc_file} \
            --VCF_OUTPUT ~{vcf_output_path} \
            --OUTPUT ~{output_file_path} \
            ~{if defined(cell_barcode_tag) then "--CELL_BARCODE_TAG " + cell_barcode_tag else ""} \
            ~{if defined(molecular_barcode_tag) then "--MOLECULAR_BARCODE_TAG " + molecular_barcode_tag else ""} \
            ~{if defined(function_tag) then "--FUNCTION_TAG " + function_tag else ""} \
            ~{if defined(edit_distance) then "--EDIT_DISTANCE " + edit_distance else ""} \
            ~{true="--IGNORED_CHROMOSOMES " false="" length(ignored_chromosomes_list) > 0}~{sep=" --IGNORED_CHROMOSOMES " ignored_chromosomes_list} \
            ~{true="--LOCUS_FUNCTION_LIST " false="" length(locus_function_list) > 0}~{sep=" --LOCUS_FUNCTION_LIST " locus_function_list} \
            ~{if defined(strand_strategy) then "--STRAND_STRATEGY " + strand_strategy else ""} \
            ~{additional_options} \
            ~{if do_cell_contamination_estimate_file then "--CELL_CONTAMINATION_ESTIMATE_FILE " + cell_contamination_estimate_file else ""} \
            ~{if defined(allele_frequency_estimate_file) then "--ALLELE_FREQUENCY_ESTIMATE_FILE " + allele_frequency_estimate_file else ""} \
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
        File vcf_output = vcf_output_path
        File vcf_output_idx = vcf_output_path + ".tbi"
        File output_file = output_file_path
    }
}
