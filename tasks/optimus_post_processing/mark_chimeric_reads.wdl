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

task mark_chimeric_reads {
    input {
        # required inputs
        File bam

        # optional inputs
        String? cell_barcode_tag # CB
        String? molecular_barcode_tag # UB
        File? cell_bc_file
        Array[String] locus_function_list = []
        String validation_stringency = "SILENT"

        # required outputs
        String output_report_path
        String output_metrics_path

        # runtime values
        String docker = "us.gcr.io/mccarroll-scrna-seq/drop-seq_private_java:current"
        Int cpu = 2
        Int memory_mb = 8192
        Int disk_gb = 10
        Int preemptible = 2
    }

    parameter_meta {
        bam: {
            localization_optional: true
        }
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

        MarkChimericReads \
            -m ${mem_size}m \
            --INPUT ~{bam} \
            ~{if defined(cell_barcode_tag) then "--CELL_BARCODE_TAG " + cell_barcode_tag else ""} \
            ~{if defined(molecular_barcode_tag) then "--MOLECULAR_BARCODE_TAG " + molecular_barcode_tag else ""} \
            ~{if defined(cell_bc_file) then "--CELL_BC_FILE " + cell_bc_file else ""} \
            ~{sep=" " prefix("--LOCUS_FUNCTION_LIST ", locus_function_list)} \
            --OUTPUT_REPORT ~{output_report_path} \
            --METRICS ~{output_metrics_path} \
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
        File output_report = output_report_path
        File output_metrics = output_metrics_path
    }
}
