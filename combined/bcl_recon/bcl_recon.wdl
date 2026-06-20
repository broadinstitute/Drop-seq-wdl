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
import "../../pipelines/reconstruction/recon_count_and_knn.wdl"
import "../../pipelines/reconstruction/recon_count_and_knn_parallel.wdl"
import "../../pipelines/reconstruction/recon_count_and_knn_serial.wdl"
import "../../pipelines/reconstruction/reconstruction.wdl"

workflow bcl_recon {
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
        File? bcl_input_tar # All the non-lane-specific files, including RunInfo.xml
        Array[File] bcl_lane_tars = [] # Lane-specific files
        Boolean bcl_only_matched_reads = false
        Boolean? reverse_complement_index_barcode_1
        Boolean? reverse_complement_index_barcode_2
        Int? lane # The single lane to run bcl_convert and recon on
        String? local_recon_dir # The directory to store the reconstruction output files
        Int? recon_count_r1_barcodes
        Int? recon_count_r2_barcodes
        Float? recon_count_downsampling_level
        Int? recon_count_n_neighbors
        Int? recon_count_bead
        Int? recon_count_chunks
        Int? recon_bead
        Array[Float]? recon_diameters
        Boolean recon_knn_filter = false
        Int? recon_n_neighbors
        Int? recon_local_connectivity
        Float? recon_spread
        Float? recon_min_dist
        Float? recon_repulsion_strength
        Int? recon_negative_sample_rate
        Array[Int?]? recon_n_epochs
    }

    Array[Int] bcl_convert_lanes = if defined(lane) then select_all([lane]) else [1, 2, 3, 4, 5, 6, 7, 8]

    call bcl_to_fastqs.bcl_to_fastqs as bcl_to_fastqs {
        input:
            barcodes_tsv = barcodes_tsv,
            bcl_dir = bcl_dir,
            bcl_convert_docker = bcl_convert_docker,
            bcl = bcl,
            local_fastq_dir = local_fastq_dir,
            bcl_convert_lanes = bcl_convert_lanes,
            bcl_only_matched_reads = bcl_only_matched_reads,
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

    # This array construction and unpack is to work around a Cromwell issue with subworkflows.
    # A scatter in a scatter creates a subworkflow call.
    # Subworkflow calls do not support optional inputs, and throw an error with the mesages:
    #   - Failed to evaluate inputs for sub workflow:
    #   - Failed to lookup input value for required input
    # The workaround is to create non-optional arrays of the optional inputs, and then unpack the arrays within the
    # inner scatter.
    Array[Int?] arr_recon_bead = [recon_bead]
    Array[Int?] arr_recon_n_neighbors = [recon_n_neighbors]
    Array[Int?] arr_recon_local_connectivity = [recon_local_connectivity]
    Array[Float?] arr_recon_spread = [recon_spread]
    Array[Float?] arr_recon_min_dist = [recon_min_dist]
    Array[Float?] arr_recon_repulsion_strength = [recon_repulsion_strength]
    Array[Int?] arr_recon_negative_sample_rate = [recon_negative_sample_rate]

    Array[Int?] selected_recon_n_epochs = select_first([recon_n_epochs, [2000, 5000]])

    if (false) {
        Float null_float = 0.0
    }

    # This will always evaluate to the result of bcl_to_fastqs.sample_ids,
    # but it makes sure that the bcl_metrics are done before we start the recon_count_and_knn scatters.
    Int sample_count = length(
        if defined(bcl_metrics.barcode_metrics_pdf) then bcl_to_fastqs.sample_ids else bcl_to_fastqs.sample_ids
    )

    scatter (sample_idx in range(sample_count)) {
        call recon_count_and_knn.recon_count_and_knn as recon_count_and_knn {
            input:
                sample_fastqs = bcl_to_fastqs.sample_fastqs[sample_idx],
                bcl_name = bcl_to_fastqs.bcl_name,
                sample_name = bcl_to_fastqs.sample_names[sample_idx],
                local_recon_dir = local_recon_dir,
                lane = lane,
                r1_barcodes = recon_count_r1_barcodes,
                r2_barcodes = recon_count_r2_barcodes,
                downsampling_level = recon_count_downsampling_level,
                n_neighbors = recon_count_n_neighbors,
                bead = recon_count_bead,
                chunks = recon_count_chunks
        }

        # call recon_count_and_knn_serial.recon_count_and_knn_serial as recon_count_and_knn_serial {
        #     input:
        #         sample_fastqs = bcl_to_fastqs.sample_fastqs[sample_idx],
        #         bcl_name = bcl_to_fastqs.bcl_name,
        #         sample_name = bcl_to_fastqs.sample_names[sample_idx],
        #         local_recon_dir = local_recon_dir,
        #         lane = lane,
        #         r1_barcodes = recon_count_r1_barcodes,
        #         r2_barcodes = recon_count_r2_barcodes,
        #         downsampling_level = recon_count_downsampling_level,
        #         n_neighbors = recon_count_n_neighbors,
        #         bead = recon_count_bead,
        #         chunks = recon_count_chunks
        # }

        call recon_count_and_knn_parallel.recon_count_and_knn_parallel as recon_count_and_knn_parallel {
            input:
                sample_fastqs = bcl_to_fastqs.sample_fastqs[sample_idx],
                bcl_name = bcl_to_fastqs.bcl_name,
                sample_name = bcl_to_fastqs.sample_names[sample_idx],
                local_recon_dir = local_recon_dir,
                lane = lane,
                r1_barcodes = recon_count_r1_barcodes,
                r2_barcodes = recon_count_r2_barcodes,
                downsampling_level = recon_count_downsampling_level,
                n_neighbors = recon_count_n_neighbors,
                bead = recon_count_bead,
                chunks = recon_count_chunks
        }

        # See comment above regarding working around subworkflow optional inputs.
        Array[File?] arr_recon_count_tar = [recon_count_and_knn.recon_count_tar]
        Array[Float?] arr_recon_diameter =
            if defined(recon_diameters) then [select_first([recon_diameters])[sample_idx]] else [null_float]

        scatter (n_epochs in selected_recon_n_epochs) {
            call reconstruction.reconstruction as reconstruction {
                input:
                    local_recon_dir = local_recon_dir,
                    bcl_name = bcl_to_fastqs.bcl_name,
                    recon_name = recon_count_and_knn.recon_name,
                    recon_count_tar = arr_recon_count_tar[0],
                    bead = arr_recon_bead[0],
                    diameter = arr_recon_diameter[0],
                    knn_filter = recon_knn_filter,
                    n_neighbors = arr_recon_n_neighbors[0],
                    local_connectivity = arr_recon_local_connectivity[0],
                    spread = arr_recon_spread[0],
                    min_dist = arr_recon_min_dist[0],
                    repulsion_strength = arr_recon_repulsion_strength[0],
                    negative_sample_rate = arr_recon_negative_sample_rate[0],
                    n_epochs = n_epochs
            }
        }

        Array[File] selected_recon_tar = select_all(reconstruction.recon_tar)
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
        Array[String] recon_names = recon_count_and_knn.recon_name
        Array[File] recon_count_tars = select_all(flatten([
            recon_count_and_knn.recon_count_tar,
            # recon_count_and_knn_serial.recon_count_tar,
            recon_count_and_knn_parallel.recon_count_tar
        ]))
        Array[File] qc_pdfs = recon_count_and_knn.qc_pdf
        Array[Array[File]] recon_tars = selected_recon_tar
        Array[Array[File]] summary_pdfs = reconstruction.summary_pdf
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
