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

task cbrb_0_3_0_tear_sheet {
    input {
        # required inputs
        File elbo_file
        File cbrb_metrics_csv
        File rb_selected_cells_file
        File cell_features_file
        File cbrb_retained_umis_file
        File read_quality_metrics_file
        String title

        # optional inputs
        Array[File] append_pdfs = []

        # required outputs
        String out_file_path

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
            -e 'message(date(), " Start ", "cbrb_0.3.0_TearSheet")' \
            -e 'suppressPackageStartupMessages(library(Dropseq.cellselection))' \
            -e 'cbrb_0.3.0_TearSheet(
                elboFile="~{elbo_file}",
                outFile="~{out_file_path}",
                cbrbMetricsCsv="~{cbrb_metrics_csv}",
                title="~{title}",
                rbSelectedCellsFile="~{rb_selected_cells_file}",
                cellFeaturesFile="~{cell_features_file}",
                cbrbRetainedUMIsFile="~{cbrb_retained_umis_file}",
                readQualityMetricsFile="~{read_quality_metrics_file}",
                appendPdfs=~{if length(append_pdfs) > 0 then "'$append_pdfs_arg'" else "c()"})' \
            -e 'message(date(), " Done ", "cbrb_0.3.0_TearSheet")'

        grep -avE '^/(Creation|Mod)Date' ~{out_file_path} > ~{out_file_path}.tmp
        mv ~{out_file_path}.tmp ~{out_file_path}
    >>>

    runtime {
        docker: docker
        cpu: cpu
        memory: memory_mb + " MB"
        disks: "local-disk " + disk_gb + " HDD"
        preemptible: preemptible
    }

    output {
        File out_file = out_file_path
    }
}
