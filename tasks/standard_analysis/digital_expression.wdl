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

task digital_expression {
    input {
        # required inputs
        File metagene_bam
        File selected_cell_barcodes
        Int edit_distance
        Int read_mq
        Int min_bc_read_threshold
        Boolean output_header
        Boolean omit_missing_cells
        String unique_experiment_id
        String gene_name_tag
        String gene_strand_tag
        String gene_function_tag

        # optional inputs
        Array[String] locus_function_list = []
        String? strand_strategy
        String validation_stringency = "SILENT"

        # required outputs
        String output_file_path
        String summary_file_path

        # runtime values
        String docker = "quay.io/broadinstitute/drop-seq_java:current"
        Int cpu = 2
        Int memory_mb = 8192
        Int disk_gb = 10
        Int preemptible = 2
    }

    parameter_meta {
        metagene_bam: {
            localization_optional: true
        }
    }

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

        DigitalExpression \
            -m ${mem_size}m \
            --INPUT ~{metagene_bam} \
            --OUTPUT ~{output_file_path} \
            --SUMMARY ~{summary_file_path} \
            --EDIT_DISTANCE ~{edit_distance} \
            --READ_MQ ~{read_mq} \
            --MIN_BC_READ_THRESHOLD ~{min_bc_read_threshold} \
            --CELL_BC_FILE ~{selected_cell_barcodes} \
            --OUTPUT_HEADER ~{output_header} \
            --OMIT_MISSING_CELLS ~{omit_missing_cells} \
            --UNIQUE_EXPERIMENT_ID ~{unique_experiment_id} \
            --GENE_NAME_TAG ~{gene_name_tag} \
            --GENE_STRAND_TAG ~{gene_strand_tag} \
            --GENE_FUNCTION_TAG ~{gene_function_tag} \
            ~{if defined(strand_strategy) then "--STRAND_STRATEGY " + strand_strategy else ""} \
            ~{true="--LOCUS_FUNCTION_LIST " false="" length(locus_function_list) > 0}~{sep=" --LOCUS_FUNCTION_LIST " locus_function_list} \
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
        File output_file = output_file_path
        File summary_file = summary_file_path
    }
}
