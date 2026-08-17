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

task list_sample_fastqs {
    input {
        # Required inputs
        Array[String] all_fastqs
        String sample_name

        # Optional inputs
        Int? sample_number
        File? barcodes_tsv
        Array[Int] lanes = []
        Array[Int] reads = []

        # Runtime values
        String docker = "quay.io/broadinstitute/drop-seq_python:2025-12-26_c9d7518"
        Int cpu = 2
        Int memory_gb = 4
        Int disk_gb = 10
        Int preemptible = 0
    }

    command <<<
        set -euo pipefail

        lanes=~{sep="," lanes}
        reads=~{sep="," reads}

        list_sample_fastqs \
            --fastqs ~{write_lines(all_fastqs)} \
            --sample-name ~{sample_name} \
            ~{if defined(sample_number) then "--sample-number " + sample_number else ""} \
            ~{if defined(barcodes_tsv) then "--barcodes " + barcodes_tsv else ""} \
            ~{if length(lanes) > 0 then "--lanes=$lanes" else ""} \
            ~{if length(reads) > 0 then "--reads=$reads" else ""} \
            --output sample_fastqs.txt
    >>>

    runtime {
        docker: docker
        cpu: cpu
        memory: memory_gb + " GB"
        disks: "local-disk " + disk_gb + " HDD"
        preemptible: preemptible
    }

    output {
        Array[String] sample_fastqs = read_lines("sample_fastqs.txt")
    }
}
