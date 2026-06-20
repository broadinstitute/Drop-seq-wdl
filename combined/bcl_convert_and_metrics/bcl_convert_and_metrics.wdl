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

import "../../pipelines/bcl_metrics/bcl_metrics.wdl"
import "../../pipelines/bcl_to_fastqs/bcl_to_fastqs.wdl"

workflow bcl_convert_and_metrics {
    input {
        # Required inputs
        File barcodes_tsv # TSV file containing the sample sheet barcodes
        String bcl_dir # The directory containing the bcl files and RunInfo.xml
        String bcl_convert_docker # Docker image containing bcl-convert
        # Optional inputs
        # The friendly name of the bcl run. This is used to name the output directories.
        # If not provided, it will be derived from the barcodes_tsv.
        String? bcl
        String? local_fastq_dir # The absolute directory to locally store the fastq files
        Array[Int] bcl_convert_lanes = [1, 2, 3, 4, 5, 6, 7, 8]
        File? bcl_input_tar # All the non-lane-specific files, including RunInfo.xml
        Array[File] bcl_lane_tars = [] # Lane-specific files
        Boolean bcl_only_matched_reads = false
        Boolean first_tile_only = false
        Boolean? reverse_complement_index_barcode_1
        Boolean? reverse_complement_index_barcode_2
        String? local_metrics_dir # The absolute directory to store the bcl metrics output files
    }

    call bcl_to_fastqs.bcl_to_fastqs as bcl_to_fastqs {
        input:
            barcodes_tsv = barcodes_tsv,
            bcl_dir = bcl_dir,
            bcl_convert_docker = bcl_convert_docker,
            bcl = bcl,
            local_fastq_dir = local_fastq_dir,
            bcl_convert_lanes = bcl_convert_lanes,
            bcl_only_matched_reads = bcl_only_matched_reads,
            first_tile_only = first_tile_only,
            bcl_input_tar = bcl_input_tar,
            bcl_lane_tars = bcl_lane_tars,
            reverse_complement_index_barcode_1 = reverse_complement_index_barcode_1,
            reverse_complement_index_barcode_2 = reverse_complement_index_barcode_2
    }

    call bcl_metrics.bcl_metrics as bcl_metrics {
        input:
            bcl_name = bcl_to_fastqs.bcl_name,
            demultiplex_stats = bcl_to_fastqs.demultiplex_stats,
            index_hopping_counts = bcl_to_fastqs.index_hopping_counts,
            top_unknown_barcodes = bcl_to_fastqs.top_unknown_barcodes,
            bcl_convert_lanes = bcl_convert_lanes,
            local_fastq_dir = local_fastq_dir
    }

    output {
        String bcl_name = bcl_to_fastqs.bcl_name
        File fastqs_file = bcl_to_fastqs.fastqs_file
        File sample_ids_file = bcl_to_fastqs.sample_ids_file
        File sample_names_file = bcl_to_fastqs.sample_names_file
        Array[String] sample_ids = bcl_to_fastqs.sample_ids
        Array[String] sample_names = bcl_to_fastqs.sample_names
        Array[Array[String]] sample_fastqs = bcl_to_fastqs.sample_fastqs
        Array[File] sample_fastqs_files = bcl_to_fastqs.sample_fastqs_files
        Array[File]? fastqs = bcl_to_fastqs.fastqs
        Array[File]? demultiplex_stats = bcl_to_fastqs.demultiplex_stats
        Array[File]? index_hopping_counts = bcl_to_fastqs.index_hopping_counts
        Array[File]? top_unknown_barcodes = bcl_to_fastqs.top_unknown_barcodes
        File? bcl_demultiplex_stats = bcl_metrics.bcl_demultiplex_stats
        File? bcl_top_unknown_barcodes = bcl_metrics.bcl_top_unknown_barcodes
        File? bcl_sample_index_report = bcl_metrics.bcl_sample_index_report
        File? barcode_metrics_pdf = bcl_metrics.barcode_metrics_pdf
    }
}
