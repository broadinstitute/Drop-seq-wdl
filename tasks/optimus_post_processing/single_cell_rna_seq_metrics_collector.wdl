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

task single_cell_rna_seq_metrics_collector {
    input {
        # required inputs
        File input_bam
        File annotations_file

        # optional inputs
        File? ribosomal_intervals
        File? cell_bc_file
        String? cell_barcode_tag # CB
        String? strand_specificity
        Int? num_core_barcodes
        Int? read_mq
        Array[String] mt_sequences = [] # ["chrM"]
        String validation_stringency = "SILENT"

        # required outputs
        String output_metrics_path

        # runtime values
        String docker = "quay.io/broadinstitute/drop-seq_java:current"
        Int cpu = 2
        Int memory_mb = 8192
        Int disk_gb = 10 + (2 * ceil(size(input_bam, "GB")))
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

        SingleCellRnaSeqMetricsCollector \
            -m ${mem_size}m \
            --INPUT ~{input_bam} \
            --ANNOTATIONS_FILE ~{annotations_file} \
            ~{if defined(ribosomal_intervals) then "--RIBOSOMAL_INTERVALS " + ribosomal_intervals else ""} \
            ~{if defined(cell_bc_file) then "--CELL_BC_FILE " + cell_bc_file else ""} \
            ~{if defined(cell_barcode_tag) then "--CELL_BARCODE_TAG " + cell_barcode_tag else ""} \
            ~{if defined(strand_specificity) then "--STRAND_SPECIFICITY " + strand_specificity else ""} \
            ~{if defined(num_core_barcodes) then "--NUM_CORE_BARCODES " + num_core_barcodes else ""} \
            ~{if defined(read_mq) then "--READ_MQ " + read_mq else ""} \
            ~{true="--MT_SEQUENCE " false="" length(mt_sequences) > 0}~{sep=" --MT_SEQUENCE " mt_sequences} \
            --OUTPUT ~{output_metrics_path} \
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
        File output_metrics = output_metrics_path
    }
}
