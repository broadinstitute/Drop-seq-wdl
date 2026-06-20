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

import "../../pipelines/reconstruction/reconstruction.wdl"

workflow recon_epochs {
    input {
        # Optional inputs
        # Either recon_count_tar OR (local_recon_dir + bcl_name + recon_name) must be provided.
        File? recon_count_tar
        String? local_recon_dir
        String? bcl_name
        String? recon_name
        Int? recon_count_r1_barcodes
        Int? recon_count_r2_barcodes
        Float? recon_count_downsampling_level
        Int? recon_count_n_neighbors
        Int? recon_count_bead
        Int? recon_count_chunks
        Int? recon_bead
        Float? recon_diameter
        Boolean recon_knn_filter = false
        Int? recon_n_neighbors
        Int? recon_local_connectivity
        Float? recon_spread
        Float? recon_min_dist
        Float? recon_repulsion_strength
        Int? recon_negative_sample_rate
        Array[Int?]? recon_n_epochs
    }

    Array[Int?] selected_recon_n_epochs = select_first([recon_n_epochs, [2000, 5000]])

    scatter (n_epochs in selected_recon_n_epochs) {
        call reconstruction.reconstruction as reconstruction {
            input:
                local_recon_dir = local_recon_dir,
                bcl_name = bcl_name,
                recon_name = recon_name,
                recon_count_tar = recon_count_tar,
                bead = recon_bead,
                diameter = recon_diameter,
                knn_filter = recon_knn_filter,
                n_neighbors = recon_n_neighbors,
                local_connectivity = recon_local_connectivity,
                spread = recon_spread,
                min_dist = recon_min_dist,
                repulsion_strength = recon_repulsion_strength,
                negative_sample_rate = recon_negative_sample_rate,
                n_epochs = n_epochs
        }
    }

    Array[File] selected_recon_tar = select_all(reconstruction.recon_tar)

    output {
        Array[File] recon_tars = selected_recon_tar
        Array[File] summary_pdfs = reconstruction.summary_pdf
    }
}
