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

task plot_alignment_metrics {
    input {
        # required inputs
        File alignment_quality_file
        File mean_quality_all_file
        File mean_quality_aligned_file
        File exon_intron_file
        File cell_bc_counts_file
        File alignment_quality_by_cell_file
        File base_pct_matrix_molecular_file
        File base_pct_matrix_cell_file

        # optional inputs
        File? exon_intron_per_cell_file
        File? start_tag_trim_file
        File? poly_a_tag_trim_file
        File? selected_cells_file
        Int? estimated_num_cells

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
            -e 'message(date(), " Start ", "plotAlignmentMetrics")' \
            -e 'suppressPackageStartupMessages(library(DropSeq.barnyard))' \
            -e 'plotAlignmentMetrics(
                alignmentQualityFile="~{alignment_quality_file}",
                meanQualityAllFile="~{mean_quality_all_file}",
                meanQualityAlignedFile="~{mean_quality_aligned_file}",
                exonIntronFile="~{exon_intron_file}",
                cellBCCountsFile="~{cell_bc_counts_file}",
                alignmentQualityByCellFile="~{alignment_quality_by_cell_file}",
                basePctMatrixMolecularFile="~{base_pct_matrix_molecular_file}",
                basePctMatrixCellFile="~{base_pct_matrix_cell_file}",
                ~{if defined(exon_intron_per_cell_file) then "exonIntronPerCellFile=\"" + exon_intron_per_cell_file + "\"," else ""}
                ~{if defined(start_tag_trim_file) then "startTagTrimFile=\"" + start_tag_trim_file + "\"," else ""}
                ~{if defined(poly_a_tag_trim_file) then "polyATagTrimFile=\"" + poly_a_tag_trim_file + "\"," else ""}
                ~{if defined(selected_cells_file) then "selectedCellsFile=\"" + selected_cells_file + "\"," else ""}
                ~{if defined(estimated_num_cells) then "estimatedNumCells=" + estimated_num_cells + "," else ""}
                outPlot="~{out_plot_path}"
            )' \
            -e 'message(date(), " Done ", "plotAlignmentMetrics")'

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
