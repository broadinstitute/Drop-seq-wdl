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

task plot_and_validate_sample_index_reports {
    input {
        # required inputs
        Array[File] unknown_barcodes_files
        Array[File] demultiplex_stats_files
        Array[File] index_hopping_files

        # optionsl inputs
        String? analysis_identifier

        # optional outputs
        Array[String] out_pdf_paths = []
        String? out_log_path

        # runtime values
        String docker = "us.gcr.io/mccarroll-scrna-seq/drop-seq_private_r:current"
        Int cpu = 2
        Int memory_mb = 8192
        Int disk_gb = 10
        Int preemptible = 0
    }

    command <<<
        set -euo pipefail

        unknown_barcodes_files_arg='c("~{sep="\",\"" unknown_barcodes_files}")'
        demultiplex_stats_files_arg='c("~{sep="\",\"" demultiplex_stats_files}")'
        index_hopping_files_arg='c("~{sep="\",\"" index_hopping_files}")'
        out_pdf_paths_arg='c("~{sep="\",\"" out_pdf_paths}")'

        Rscript \
            -e 'message(date(), " Start ", "plotAndValidateSampleIndexReports")' \
            -e 'suppressPackageStartupMessages(library(DropSeq.illumina))' \
            -e 'plotAndValidateSampleIndexReports(
                unknownBarcodesFiles=~{if length(unknown_barcodes_files) > 0 then "'$unknown_barcodes_files_arg'" else "c()"},
                demultiplexStatsFiles=~{if length(demultiplex_stats_files) > 0 then "'$demultiplex_stats_files_arg'" else "c()"},
                indexHoppingFiles=~{if length(index_hopping_files) > 0 then "'$index_hopping_files_arg'" else "c()"},
                analysisIdentifier=~{if defined(analysis_identifier) then "\"" + analysis_identifier + "\"" else "NULL"},
                outPdfs=~{if length(out_pdf_paths) > 0 then "'$out_pdf_paths_arg'" else "NULL"},
                outLog=~{if defined(out_log_path) then "\"" + out_log_path + "\"" else "NULL"}
            )' \
            -e 'message(date(), " Done ", "plotAndValidateSampleIndexReports")'

        for out_pdf_path in ~{sep=" " out_pdf_paths}; do
            grep -avE '^/(Creation|Mod)Date' $out_pdf_path > $out_pdf_path.tmp
            mv $out_pdf_path.tmp $out_pdf_path
        done
    >>>

    runtime {
        docker: docker
        cpu: cpu
        memory: memory_mb + " MB"
        disks: "local-disk " + disk_gb + " HDD"
        preemptible: preemptible
    }

    output {
        Array[File] out_pdfs = out_pdf_paths
        File? out_log = out_log_path
    }
}
