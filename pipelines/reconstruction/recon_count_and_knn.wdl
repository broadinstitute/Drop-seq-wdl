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

import "../../tasks/reconstruction/knn.wdl"
import "../../tasks/reconstruction/recon_count.wdl"
import "../../tasks/reconstruction/untar.wdl"
import "../../tasks/reconstruction/validate_recon_inputs.wdl"

workflow recon_count_and_knn {
    input {
        # Required inputs
        Array[File] sample_fastqs
        String bcl_name
        String sample_name

        # Optional inputs
        String? local_recon_dir
        Int? lane
        Int? r1_barcodes
        Int? r2_barcodes
        Float? downsampling_level
        Int? n_neighbors
        Int? bead
        Int? chunks
        Float recon_count_memory_multiplier = 1.8
        # Adjust the relative heap size as julia's heap size settings is only a soft hint, not a hard ceiling.
        # https://discourse.julialang.org/t/heap-size-hint-usage-recommendations/98697
        Float? recon_count_heap_fraction
        File? recon_count_jl
        Float knn_memory_multiplier = 0.75
        File? knn_py
    }

    # If we try to strip the fastq extensions from the fastq filenames and they remain unchanged
    # then the input fastqs are likely files containing lists of fastq paths.
    if (basename(sample_fastqs[0]) == basename(sample_fastqs[0], ".fastq") &&
        basename(sample_fastqs[0]) == basename(sample_fastqs[0], ".fastq.gz")) {
        scatter (sample_fastqs_file in sample_fastqs) {
            Array[String] sample_fastqs_lines = read_lines(sample_fastqs[0])
        }

        Array[String] sample_fastqs_flattened = flatten(sample_fastqs_lines)
    }

    # Calculate the memory needed for recon_count_and_knn, based on an example notebook provided by the Macosko lab
    Array[File] sample_fastqs_selected = select_first([sample_fastqs_flattened, sample_fastqs])
    Float fastqs_size_gb = size(sample_fastqs_selected, "GB")
    Int fastqs_memory_gb = ceil(1.5 * fastqs_size_gb)
    Int recon_count_memory_gb =
        if fastqs_size_gb * recon_count_memory_multiplier > 16
        then ceil(fastqs_size_gb * recon_count_memory_multiplier)
        else 16
    Int knn_memory_gb =
        if fastqs_size_gb * knn_memory_multiplier > 16
        then ceil(fastqs_size_gb * knn_memory_multiplier)
        else 16

    call validate_recon_inputs.validate_recon_inputs as validate_recon_inputs {
        input:
            bcl = bcl_name,
            sample_name = sample_name,
            lane = lane,
            r1_barcodes = r1_barcodes,
            r2_barcodes = r2_barcodes,
            downsampling_level = downsampling_level
    }

    call recon_count.recon_count as recon_count {
        input:
            bcl = bcl_name,
            recon_name = validate_recon_inputs.recon_name,
            fastqs = sample_fastqs_selected,
            downsampling_level = downsampling_level,
            r1_barcodes = r1_barcodes,
            r2_barcodes = r2_barcodes,
            recon_count_jl = recon_count_jl,
            memory_gb = recon_count_memory_gb,
            heap_fraction = recon_count_heap_fraction
    }

    call knn.knn as knn {
        input:
            tar_suffix = "original",
            bcl = bcl_name,
            recon_name = validate_recon_inputs.recon_name,
            recon_count_files = recon_count.recon_count_outputs,
            n_neighbors = n_neighbors,
            bead = bead,
            chunks = chunks,
            knn_py = knn_py,
            memory_gb = knn_memory_gb
    }

    # TODO: After testing, restore to either untarring or returning the tar
    if (defined(local_recon_dir)) {
        call untar.untar as untar {
            input:
                tar_file = knn.recon_count_tar,
                target_directory = select_first([local_recon_dir])
        }
    }

    #if (!defined(local_recon_dir)) {
        File opt_recon_count_tar = knn.recon_count_tar
    #}

    output {
        String recon_name = validate_recon_inputs.recon_name
        File qc_pdf = recon_count.qc_pdf
        File? recon_count_tar = opt_recon_count_tar
    }
}
