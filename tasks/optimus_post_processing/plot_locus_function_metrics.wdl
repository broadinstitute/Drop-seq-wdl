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

task plot_locus_function_metrics {
    input {
        # required inputs
        File digital_expression_summary_file
        File exon_intron_per_cell_file
        File cell_bc_counts_file
        Int estimated_num_cells

        # required outputs
        String out_plot_path

        # runtime values
        String docker = "us.gcr.io/mccarroll-scrna-seq/drop-seq_private_r:current"
        Int cpu = 2
        Int memory_mb = 16384
        Int disk_gb = 10
        Int preemptible = 2
    }

    command <<<
        set -euo pipefail

        Rscript \
            -e 'message(date(), " Start ", "plotLocusFunctionMetrics")' \
            -e 'suppressPackageStartupMessages(library(DropSeq.barnyard))' \
            -e 'plotLocusFunctionMetrics(
                digitalExpressionSummaryFile="~{digital_expression_summary_file}",
                exonIntronPerCellFile="~{exon_intron_per_cell_file}",
                cellBCCountsFile="~{cell_bc_counts_file}",
                estimatedNumCells=~{estimated_num_cells},
                outPlot="~{out_plot_path}"
            )' \
            -e 'message(date(), " Done ", "plotLocusFunctionMetrics")'

        grep -avE '^/(Creation|Mod)Date' ~{out_plot_path} > ~{out_plot_path}.tmp
        mv ~{out_plot_path}.tmp ~{out_plot_path}
    >>>

    runtime {
        docker: docker
        cpu: cpu
        memory: memory_mb + " MB"
        disks: "local-disk " + disk_gb + " HDD"
        preemptible: preemptible
    }

    output {
        File out_plot = out_plot_path
    }
}
