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

task plot_diversity {
    input {
        # required inputs
        File metacells

        # required outputs
        String pdf_path

        # runtime values
        String docker = "quay.io/broadinstitute/drop-seq_r:current"
        Int cpu = 2
        Int memory_mb = 4096
        Int disk_gb = 10
        Int preemptible = 2
    }

    # Use grep -avE to strip out the internal modification time for reproducibility.
    command <<<
        set -euo pipefail

        Rscript \
            -e 'message(date(), " Start ", "plotDiversity")' \
            -e 'suppressPackageStartupMessages(library(DropSeq.eqtl))' \
            -e 'plotDiversity(
                metaCellFile="~{metacells}",
                outPDF="~{pdf_path}"
            )' \
            -e 'message(date(), " Done ", "plotDiversity")'

        grep -avE '^/(Creation|Mod)Date' ~{pdf_path} > ~{pdf_path}.tmp
        mv ~{pdf_path}.tmp ~{pdf_path}
    >>>

    runtime {
        docker: docker
        cpu: cpu
        memory: memory_mb + " MB"
        disks: "local-disk " + disk_gb + " HDD"
        preemptible: preemptible
    }

    output {
        File pdf = pdf_path
    }
}
