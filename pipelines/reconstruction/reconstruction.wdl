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

import "../../tasks/reconstruction/get_matrix_size.wdl"
import "../../tasks/reconstruction/recon.wdl"
import "../../tasks/reconstruction/tar_and_get_matrix_size.wdl"
import "../../tasks/reconstruction/untar.wdl"

workflow reconstruction {
    input {
        # Optional inputs
        # Either recon_count_tar OR (local_recon_dir + bcl_name + recon_name) must be provided.
        File? recon_count_tar
        String? local_recon_dir
        String? bcl_name
        String? recon_name
        Int? bead
        Float? diameter
        Boolean knn_filter = false
        Int? n_neighbors
        Int? local_connectivity
        Float? spread
        Float? min_dist
        Float? repulsion_strength
        Int? negative_sample_rate
        Int? n_epochs
        # Increase the memory as python programs in the docker image were running out of memory with exit code 137 but
        # NOT printing (flushing?) a "Killed" error to stderr so cromwell retry-with-more-memory wasn't working.
        Float recon_memory_multiplier = 1.2
        File? recon_py
        File? helpers_py
    }

    if (defined(recon_count_tar)) {
        call get_matrix_size.get_matrix_size as get_matrix_size {
            input:
                recon_count_tar = select_first([recon_count_tar])
        }
    }

    if (!defined(recon_count_tar)) {
        call tar_and_get_matrix_size.tar_and_get_matrix_size as tar_and_get_matrix_size {
            input:
                local_recon_dir = select_first([local_recon_dir]),
                bcl_name = select_first([bcl_name]),
                recon_name = select_first([recon_name])
        }
    }

    # Calculate the memory needed for recon, based on an example notebook provided by the Macosko lab
    Float matrix_size_gb = select_first([get_matrix_size.matrix_gb, tar_and_get_matrix_size.matrix_gb])
    Int matrix_memory_gb = ceil(25 * matrix_size_gb)
    Int recon_memory_gb = if matrix_memory_gb > 16 then matrix_memory_gb else 16
    # Scale the cpus to match the memory
    Float recon_gb_per_cpu = 16.0
    Int recon_cpu_step =  4 # Increase cpus in steps of 4
    Int recon_cpu_min = 16
    Int recon_cpu_max = 48
    Int recon_cpu_calc = ceil(recon_memory_gb / recon_gb_per_cpu / recon_cpu_step) * recon_cpu_step
    Int recon_cpu =
        if recon_cpu_calc < recon_cpu_min then recon_cpu_min
        else if recon_cpu_calc > recon_cpu_max then recon_cpu_max
        else recon_cpu_calc

    call recon.recon as recon {
        input:
            bcl = select_first([get_matrix_size.bcl_name, bcl_name]),
            recon_name = select_first([get_matrix_size.recon_name, recon_name]),
            recon_count_tar = select_first([recon_count_tar, tar_and_get_matrix_size.recon_count_tar]),
            bead = bead,
            diameter = diameter,
            knn_filter = knn_filter,
            n_neighbors = n_neighbors,
            n_neighbors = n_neighbors,
            local_connectivity = local_connectivity,
            spread = spread,
            min_dist = min_dist,
            repulsion_strength = repulsion_strength,
            negative_sample_rate = negative_sample_rate,
            n_epochs = n_epochs,
            recon_py = recon_py,
            helpers_py = helpers_py,
            cpu = recon_cpu,
            memory_gb = ceil(recon_memory_gb * recon_memory_multiplier)
    }

    if (defined(local_recon_dir)) {
        call untar.untar as untar {
            input:
                tar_file = recon.recon_tar,
                target_directory = select_first([local_recon_dir])
        }
    }

    if (!defined(local_recon_dir)) {
        File output_tar = recon.recon_tar
    }

    output {
        File summary_pdf = recon.summary_pdf
        File? recon_tar = output_tar
    }
}
