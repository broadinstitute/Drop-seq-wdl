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

import "../../pipelines/reconstruction/recon_count_and_knn.wdl"
import "../../pipelines/reconstruction/recon_count_and_knn_parallel.wdl"
import "../../pipelines/reconstruction/recon_count_and_knn_serial.wdl"
import "../../pipelines/reconstruction/reconstruction.wdl"

workflow fastqs_recon_count_and_knn {
    input {
        # Required inputs
        Array[File] sample_fastqs
        String bcl_name
        String sample_name

        # Optional inputs
        String? local_recon_dir # The directory to store the reconstruction output files
        Int? lane # The single lane to run recon on
        Int? recon_count_r1_barcodes
        Int? recon_count_r2_barcodes
        Float? recon_count_downsampling_level
        Int? recon_count_n_neighbors
        Int? recon_count_bead
        Int? recon_count_chunks
    }

    call recon_count_and_knn.recon_count_and_knn as recon_count_and_knn {
        input:
            sample_fastqs = sample_fastqs,
            bcl_name = bcl_name,
            sample_name = sample_name,
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
    #         sample_fastqs = sample_fastqs,
    #         bcl_name = bcl_name,
    #         sample_name = sample_name,
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
            sample_fastqs = sample_fastqs,
            bcl_name = bcl_name,
            sample_name = sample_name,
            local_recon_dir = local_recon_dir,
            lane = lane,
            r1_barcodes = recon_count_r1_barcodes,
            r2_barcodes = recon_count_r2_barcodes,
            downsampling_level = recon_count_downsampling_level,
            n_neighbors = recon_count_n_neighbors,
            bead = recon_count_bead,
            chunks = recon_count_chunks
    }

    output {
        String recon_name = recon_count_and_knn.recon_name
        Array[File] recon_count_tars = select_all([
            recon_count_and_knn.recon_count_tar,
            # recon_count_and_knn_serial.recon_count_tar,
            recon_count_and_knn_parallel.recon_count_tar
        ])
        File qc_pdfs = recon_count_and_knn.qc_pdf
    }
}
