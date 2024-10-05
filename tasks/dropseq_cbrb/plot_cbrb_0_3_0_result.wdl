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

task plot_cbrb_0_3_0_result {
    input {
        # required inputs
        File contamination_fraction_params_file
        File rb_num_transcripts_file
        File rb_selected_cells_file
        File cell_features_file
        File cbrb_metrics_csv
        String lib_name

        # optional inputs
        Array[File] append_pdfs = []

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

        append_pdfs_arg='c("~{sep="\",\"" append_pdfs}")'

        Rscript \
            -e 'message(date(), " Start ", "plotCbrb_0.3.0_Result")' \
            -e 'suppressPackageStartupMessages(library(Dropseq.cellselection))' \
            -e 'plotCbrb_0.3.0_Result(
                outPdf="~{out_pdf_path}",
                libName="~{lib_name}",
                contaminationFractionParamsFile="~{contamination_fraction_params_file}",
                rbNumTranscriptsFile="~{rb_num_transcripts_file}",
                appendPdfs=~{if length(append_pdfs) > 0 then "'$append_pdfs_arg'" else "c()"},
                cbrbMetricsCsv="~{cbrb_metrics_csv}",
                rbSelectedCellsFile="~{rb_selected_cells_file}",
                cellFeaturesFile="~{cell_features_file}"
            )' \
            -e 'message(date(), " Done ", "plotCbrb_0.3.0_Result")'

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
