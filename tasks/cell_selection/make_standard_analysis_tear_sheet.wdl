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

task make_standard_analysis_tear_sheet {
    input {
        # required inputs
        File alignment_quality_file

        # optional inputs
        File? cell_selection_summary_file
        File? chimeric_read_metrics_file
        Array[File] barcode_metrics_files = []

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

        barcode_metrics_arg='c("~{sep="\",\"" barcode_metrics_files}")'

        Rscript \
            -e 'message(date(), " Start ", "makeStandardAnalysisTearSheet")' \
            -e 'suppressPackageStartupMessages(library(DropSeq.barnyard.private))' \
            -e 'makeStandardAnalysisTearSheet(
                outFile="~{out_file_path}",
                alignmentQualityFile="~{alignment_quality_file}",
                ~{if length(barcode_metrics_files) > 0 then "barcode_metrics='$barcode_metrics_arg'," else ""}
                cellSelectionSummaryFile=~{if defined(cell_selection_summary_file) then "\"" + cell_selection_summary_file + "\"" else "NULL"},
                chimericReadMetricsFile=~{if defined(chimeric_read_metrics_file) then "\"" + chimeric_read_metrics_file + "\"" else "NULL"}
            )' \
            -e 'message(date(), " Done ", "makeStandardAnalysisTearSheet")'
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
