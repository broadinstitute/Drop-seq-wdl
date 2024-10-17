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

task plateau_plot_pdf_clp {
    input {
        # required inputs
        File cell_features_file
        String title

        # optional inputs
        Int? total_droplets_included
        Int? expected_cells
        File? svm_cbrb_parameter_estimation_file

        # required outputs
        String out_pdf_path

        # runtime values
        String docker = "us.gcr.io/mccarroll-scrna-seq/drop-seq_private_r:current"
        Int cpu = 2
        Int memory_mb = 4096
        Int disk_gb = 10
        Int preemptible = 2
    }

    command <<<
        set -euo pipefail

        Rscript \
            -e 'message(date(), " Start ", "plateauPlotPdfClp")' \
            -e 'suppressPackageStartupMessages(library(Dropseq.cellselection))' \
            -e 'plateauPlotPdfClp(
                cellFeaturesFile="~{cell_features_file}",
                title="~{title}",
                total_droplets_included=~{if defined(total_droplets_included) then total_droplets_included else "NULL"},
                expected_cells=~{if defined(expected_cells) then expected_cells else "NULL"},
                svmCbrbParameterEstimationFile=~{if defined(svm_cbrb_parameter_estimation_file) then "\"" + svm_cbrb_parameter_estimation_file + "\"" else "NULL"},
                outPdf="~{out_pdf_path}"
            )' \
            -e 'message(date(), " Done ", "plateauPlotPdfClp")'

        grep -avE '^/(Creation|Mod)Date' ~{out_pdf_path} > ~{out_pdf_path}.tmp
        mv ~{out_pdf_path}.tmp ~{out_pdf_path}
    >>>

    runtime {
        docker: docker
        cpu: cpu
        memory: memory_mb + " MB"
        disks: "local-disk " + disk_gb + " HDD"
        preemptible: preemptible
    }

    output {
        File out_pdf = out_pdf_path
    }
}
