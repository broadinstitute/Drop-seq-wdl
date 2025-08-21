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

task merge_dge {
    input {
        # required inputs
        Array[File] input_expression

        # optional inputs
        Boolean integer_format = true
        Boolean output_header = true
        String header_stringency = "STRICT"
        String? feature_type
        String? output_format
        String validation_stringency = "SILENT"

        # required outputs
        String output_file_path

        # optional outputs
        String? output_genes_path
        String? output_cells_path
        String? output_features_path

        # runtime values
        String docker = "quay.io/broadinstitute/drop-seq_java:current"
        Int cpu = 2
        Int memory_mb = 8192
        Int disk_gb = 10
        Int preemptible = 2
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

        MergeDge \
            -m ${mem_size}m \
            ~{true="--INPUT " false="" length(input_expression) > 0}~{sep=" --INPUT " input_expression} \
            --INTEGER_FORMAT ~{integer_format} \
            --HEADER_STRINGENCY ~{header_stringency} \
            --OUTPUT_HEADER ~{output_header} \
            --OUTPUT ~{output_file_path} \
            ~{if defined(output_genes_path) then "--OUTPUT_GENES " + output_genes_path else ""} \
            ~{if defined(output_cells_path) then "--OUTPUT_CELLS " + output_cells_path else ""} \
            ~{if defined(output_features_path) then "--OUTPUT_FEATURES " + output_features_path else ""} \
            ~{if defined(feature_type) then "--FEATURE_TYPE " + feature_type else ""} \
            ~{if defined(output_format) then "--OUTPUT_FORMAT " + output_format else ""} \
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
        File? output_genes = output_genes_path
        File? output_cells = output_cells_path
        File? output_features = output_features_path
    }
}
