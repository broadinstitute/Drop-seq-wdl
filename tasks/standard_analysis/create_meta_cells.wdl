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

task create_meta_cells {
    input {
        # required inputs
        File input_expression

        # optional inputs
        String? single_metacell_label
        String? metacell_column
        File? donor_cell_map
        String validation_stringency = "SILENT"

        # required outputs
        String output_file_path

        # optional outputs
        String? metrics_file_path

        # runtime values
        String docker = "us.gcr.io/mccarroll-scrna-seq/drop-seq_private_java:current"
        Int cpu = 2
        Int memory_mb = 8192
        Int disk_gb = 10
        Int preemptible = 2
    }

    command <<<
        set -euo pipefail

        mem_unit=${MEM_UNIT%?}
        if [[ $mem_unit == "M" ]]; then
            mem_size=$(awk "BEGIN {print int($MEM_SIZE)}")
        elif [[ $mem_unit == "G" ]]; then
            mem_size=$(awk "BEGIN {print int($MEM_SIZE * 1024)}")
        else
            echo "Unsupported memory unit: $MEM_UNIT" 1>&2
            exit 1
        fi
        mem_size=$(awk "BEGIN {print int($mem_size * 7 / 8)}")

        CreateMetaCells \
            -m ${mem_size}m \
            --INPUT ~{input_expression} \
            ~{if defined(single_metacell_label) then "--SINGLE_METACELL_LABEL " + single_metacell_label else ""} \
            ~{if defined(metacell_column) then "--METACELL_COLUMN " + metacell_column else ""} \
            ~{if defined(donor_cell_map) then "--DONOR_MAP " + donor_cell_map else ""} \
            ~{if defined(metrics_file_path) then "--METRICS " + metrics_file_path else ""} \
            --OUTPUT ~{output_file_path} \
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
        File? metrics_file = metrics_file_path
    }
}
