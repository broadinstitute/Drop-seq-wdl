# MIT License
#
# Copyright 2026 Broad Institute
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

task list_barcode_samples {
    input {
        # Required inputs
        File barcodes_tsv
        String output_prefix

        # Runtime values
        String docker = "quay.io/broadinstitute/drop-seq_python:2025-12-26_c9d7518"
        Int cpu = 2
        Int memory_gb = 4
        Int disk_gb = 10
        Int preemptible = 0
    }

    command <<<
        set -euo pipefail

        list_barcode_samples \
            --barcodes ~{barcodes_tsv} \
            --ids ~{output_prefix}.sample_ids.txt \
            --names ~{output_prefix}.sample_names.txt
    >>>

    runtime {
        docker: docker
        cpu: cpu
        memory: memory_gb + " GB"
        disks: "local-disk " + disk_gb + " HDD"
        preemptible: preemptible
    }

    output {
        File sample_ids_file = output_prefix + ".sample_ids.txt"
        File sample_names_file = output_prefix + ".sample_names.txt"
        Array[String] sample_ids = read_lines(sample_ids_file)
        Array[String] sample_names = read_lines(sample_names_file)
    }
}
