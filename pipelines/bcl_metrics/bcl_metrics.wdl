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

import "../../tasks/bcl_metrics/plot_and_validate_sample_index_reports.wdl"
import "../../tasks/bcl_metrics/summarize_dumultiplex_stats.wdl"
import "../../tasks/bcl_metrics/summarize_top_unknown_barcodes.wdl"
import "../../tasks/common/copy_file.wdl"

workflow bcl_metrics {
    input {
        # required inputs
        String bcl_name

        # optional inputs
        # Either (demultiplex_stats + index_hopping_counts + top_unknown_barcodes) OR (local_fastq_dir) must be provided
        Array[File]? demultiplex_stats
        Array[File]? index_hopping_counts
        Array[File]? top_unknown_barcodes
        Array[Int] bcl_convert_lanes = [1, 2, 3, 4, 5, 6, 7, 8]
        String? local_fastq_dir # The absolute directory to locally storing the fastq reports and metrics
    }

    Boolean use_files_args = defined(top_unknown_barcodes) && defined(demultiplex_stats) && defined(index_hopping_counts)

    if (!use_files_args) {
        scatter (lane in bcl_convert_lanes) {
            String lane_reports_dir = local_fastq_dir + "/" + bcl_name + "/" + lane + "/Reports"
            File demultiplex_stats_file = lane_reports_dir + "/Demultiplex_Stats.csv"
            File index_hopping_counts_file = lane_reports_dir + "/Index_Hopping_Counts.csv"
            File top_unknown_barcodes_file = lane_reports_dir + "/Top_Unknown_Barcodes.csv"
        }
    }

    Array[File] demultiplex_stats_files = select_first([demultiplex_stats_file, demultiplex_stats])
    Array[File] index_hopping_files = select_first([index_hopping_counts_file, index_hopping_counts])
    Array[File] top_unknown_barcodes_files = select_first([top_unknown_barcodes_file, top_unknown_barcodes])

    call summarize_dumultiplex_stats.summarize_dumultiplex_stats as summarize_dumultiplex_stats {
        input:
            demultiplex_stats_files = demultiplex_stats_files,
            out_file_path = "Demultiplex_Stats.tsv"
    }

    call summarize_top_unknown_barcodes.summarize_top_unknown_barcodes as summarize_top_unknown_barcodes {
        input:
            demultiplex_stats_files = demultiplex_stats_files,
            unknown_barcodes_files = top_unknown_barcodes_files,
            out_file_path = "Top_Unknown_Barcodes.csv"
    }

    call plot_and_validate_sample_index_reports.plot_and_validate_sample_index_reports as plot_and_validate_sample_index_reports {
        input:
            unknown_barcodes_files = [summarize_top_unknown_barcodes.out_file],
            demultiplex_stats_files = demultiplex_stats_files,
            index_hopping_files = index_hopping_files,
            analysis_identifier = bcl_name,
            out_pdf_paths = ["barcode_metrics.pdf"],
            out_log_path = "sample_index_report.log"
    }

    Boolean has_barcode_metrics = length(plot_and_validate_sample_index_reports.out_pdfs) > 0

    if (defined(local_fastq_dir)) {
        String bcl_dir = local_fastq_dir + "/" + bcl_name

        call copy_file.copy_file as copy_file_demultiplex_stats {
            input:
                input_file = summarize_dumultiplex_stats.out_file,
                out_path = bcl_dir + "/Demultiplex_Stats.tsv"
        }

        call copy_file.copy_file as copy_file_top_unknown_barcodes {
            input:
                input_file = summarize_top_unknown_barcodes.out_file,
                out_path = bcl_dir + "/Top_Unknown_Barcodes.csv"
        }

        if (defined(plot_and_validate_sample_index_reports.out_log)) {
            call copy_file.copy_file as copy_file_sample_index_report {
                input:
                    input_file = select_first([plot_and_validate_sample_index_reports.out_log]),
                    out_path = bcl_dir + "/sample_index_report.log"
            }
        }

        if (has_barcode_metrics) {
            call copy_file.copy_file as copy_file_barcode_metrics {
                input:
                    input_file = plot_and_validate_sample_index_reports.out_pdfs[0],
                    out_path = bcl_dir + "/barcode_metrics.pdf"
            }
        }
    }

    if (!defined(local_fastq_dir)) {
        File opt_bcl_demultiplex_stats = summarize_dumultiplex_stats.out_file
        File opt_bcl_top_unknown_barcodes = summarize_top_unknown_barcodes.out_file
        File? opt_bcl_sample_index_report = plot_and_validate_sample_index_reports.out_log
        if (has_barcode_metrics) {
            File opt_barcode_metrics_pdf = plot_and_validate_sample_index_reports.out_pdfs[0]
        }
    }

    output {
        File? bcl_demultiplex_stats = opt_bcl_demultiplex_stats
        File? bcl_top_unknown_barcodes = opt_bcl_top_unknown_barcodes
        File? bcl_sample_index_report = opt_bcl_sample_index_report
        File? barcode_metrics_pdf = opt_barcode_metrics_pdf
    }
}
