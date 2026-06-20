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

task summarize_top_unknown_barcodes {
    input {
        # required inputs
        Array[File] demultiplex_stats_files
        Array[File] unknown_barcodes_files

        # optional inputs
        Int? num_to_report

        # required outputs
        String out_file_path

        # runtime values
        String docker = "us.gcr.io/mccarroll-scrna-seq/drop-seq_private_r:current"
        Int cpu = 2
        Int memory_mb = 8192
        Int disk_gb = 10
        Int preemptible = 0
    }

    command <<<
        set -euo pipefail

        report_dirs_arg="c(\""
        for idx in $(seq 1 ~{length(demultiplex_stats_files)}); do
            mkdir $idx
            if [ $idx -gt 1 ]; then
                report_dirs_arg="${report_dirs_arg}\",\""
            fi
            report_dirs_arg="${report_dirs_arg}${idx}"
        done
        report_dirs_arg="${report_dirs_arg}\")"

        idx=1
        for demultiplex_stats_file in ~{sep=" " demultiplex_stats_files}; do
            ln -s $demultiplex_stats_file $idx/Demultiplex_Stats.csv
            idx=$((idx + 1))
        done

        idx=1
        for unknown_barcodes_file in ~{sep=" " unknown_barcodes_files}; do
            ln -s $unknown_barcodes_file $idx/Top_Unknown_Barcodes.csv
            idx=$((idx + 1))
        done

        Rscript \
            -e 'message(date(), " Start ", "summarizeTopUnknownBarcodes")' \
            -e 'suppressPackageStartupMessages(library(DropSeq.illumina))' \
            -e 'summarizeTopUnknownBarcodes(
                reportDirs='"$report_dirs_arg"',
                ~{if defined(num_to_report) then "numToReport=" + num_to_report + "," else ""}
                outFile="~{out_file_path}"
            )' \
            -e 'message(date(), " Done ", "summarizeTopUnknownBarcodes")'
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
