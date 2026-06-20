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

import "../../tasks/common/concat_files.wdl"
import "../../tasks/reconstruction/knn.wdl"
import "../../tasks/reconstruction/recon_count_compute_chimeras.wdl"
import "../../tasks/reconstruction/recon_count_compute_whitelists.wdl"
import "../../tasks/reconstruction/recon_count_count_reads.wdl"
import "../../tasks/reconstruction/recon_count_count_umis.wdl"
import "../../tasks/reconstruction/recon_count_find_fastqs.wdl"
import "../../tasks/reconstruction/recon_count_match_whitelists.wdl"
import "../../tasks/reconstruction/recon_count_read_fastqs.wdl"
import "../../tasks/reconstruction/recon_count_remove_chimeras.wdl"
import "../../tasks/reconstruction/untar.wdl"
import "../../tasks/reconstruction/validate_recon_inputs.wdl"

workflow recon_count_and_knn_parallel {
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
        # Memory scale for smaller jobs that are not aggregating data
        Float recon_count_scatter_memory_multiplier = 0.2
        # Memory scale for larger jobs that need to aggregate data
        Float recon_count_gather_memory_multiplier = 0.5
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
    Int recon_count_scatter_memory_gb =
        if fastqs_size_gb * recon_count_scatter_memory_multiplier > 16
        then ceil(fastqs_size_gb * recon_count_scatter_memory_multiplier)
        else 16
    Int recon_count_gather_memory_gb =
        if fastqs_size_gb * recon_count_gather_memory_multiplier > 16
        then ceil(fastqs_size_gb * recon_count_gather_memory_multiplier)
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

    Array[String] bases = ["A", "C", "G", "T"]
    scatter(base1 in bases) {
        scatter(base2 in bases) {
            Array[String] prefix_pair = [base1, base2]
        }
        Array[String] prefix_pair_n1 = [base1, "N"]
        Array[String] prefix_pair_n2 = ["N", base1]
    }
    Array[Array[String]] prefix_pairs = flatten(prefix_pair)
    Array[Array[String]] prefix_pair_ns = flatten([prefix_pair_n1, prefix_pair_n2, [["N", "N"]]])

    call recon_count_find_fastqs.recon_count_find_fastqs as recon_count_find_fastqs {
        input:
            bcl = bcl_name,
            recon_name = validate_recon_inputs.recon_name,
            fastqs = sample_fastqs_selected,
            memory_gb = recon_count_scatter_memory_gb,
            heap_fraction = recon_count_heap_fraction
    }

    scatter(idx in range(length(prefix_pairs))) {
        Array[String] read_fastqs_prefix_pair = prefix_pairs[idx]

        call recon_count_read_fastqs.recon_count_read_fastqs as recon_count_read_fastqs {
            input:
                bcl = bcl_name,
                find_fastqs_metadata_csv = recon_count_find_fastqs.metadata_csv,
                find_fastqs_fastqs_txts = recon_count_find_fastqs.fastqs_txts,
                fastqs = sample_fastqs_selected,
                downsampling_level = downsampling_level,
                r1_filter = read_fastqs_prefix_pair[0],
                r2_filter = read_fastqs_prefix_pair[1],
                memory_gb = recon_count_scatter_memory_gb,
                heap_fraction = recon_count_heap_fraction
        }
    }

    # Calculate metadata for reads with Ns in the barcode positions
    scatter(idx in range(length(prefix_pair_ns))) {
        Array[String] read_fastqs_prefix_pair_n = prefix_pair_ns[idx]

        call recon_count_read_fastqs.recon_count_read_fastqs as recon_count_read_fastqs_n {
            input:
                bcl = bcl_name,
                find_fastqs_metadata_csv = recon_count_find_fastqs.metadata_csv,
                find_fastqs_fastqs_txts = recon_count_find_fastqs.fastqs_txts,
                fastqs = sample_fastqs_selected,
                downsampling_level = downsampling_level,
                r1_filter = read_fastqs_prefix_pair_n[0],
                r2_filter = read_fastqs_prefix_pair_n[1],
                # Use the default memory as we're only calculating metadata
                heap_fraction = recon_count_heap_fraction
        }
    }

    # If/when the reads_per_umi.csv and readumi_per_sb*_csv.gz files are commented back in, merge them
    # https://github.com/MacoskoLab/Macosko-Pipelines/commit/e7cdbce14b548563ed2bee8d9c97f471a5c8bc0b#diff-784f27f13495c960acbc0c3b9a700d92f22d2289d5669d552192382ecebcacf9R537-R556

    if (length(select_all(recon_count_read_fastqs.reads_per_umi_csv)) > 0) {
        call recon_count_count_reads.recon_count_count_reads as recon_count_count_reads_rpu {
            input:
                read_fastqs_reads_per_umi_csvs = select_all(recon_count_read_fastqs.reads_per_umi_csv),
                # Use the default memory as reads_per_umi.csv are usually 20 lines or less
                heap_fraction = recon_count_heap_fraction
        }
    }

    if (length(select_all(recon_count_read_fastqs.readumi_per_sb1_csv_gz)) > 0) {
        scatter (count_reads_base_rupsb1 in bases) {
            call recon_count_count_reads.recon_count_count_reads as recon_count_count_reads_rupsb1 {
                input:
                    r1_filter = count_reads_base_rupsb1,
                    read_fastqs_readumi_per_sb1_csv_gzs = select_all(recon_count_read_fastqs.readumi_per_sb1_csv_gz),
                    memory_gb = recon_count_gather_memory_gb,
                    heap_fraction = recon_count_heap_fraction
            }
        }

        call concat_files.concat_files as concat_rupsb1 {
            input:
                files = flatten(recon_count_count_reads_rupsb1.readumi_per_sb1_csv_gzs),
                header_count = 1,
                out_path = "readumi_per_sb1.csv.gz"
        }
    }

    if (length(select_all(recon_count_read_fastqs.readumi_per_sb2_csv_gz)) > 0) {
        scatter (count_reads_base_rupsb2 in bases) {
            call recon_count_count_reads.recon_count_count_reads as recon_count_count_reads_rupsb2 {
                input:
                    r2_filter = count_reads_base_rupsb2,
                    read_fastqs_readumi_per_sb2_csv_gzs = select_all(recon_count_read_fastqs.readumi_per_sb2_csv_gz),
                    memory_gb = recon_count_gather_memory_gb,
                    heap_fraction = recon_count_heap_fraction
            }
        }

        call concat_files.concat_files as concat_rupsb2 {
            input:
                files = flatten(recon_count_count_reads_rupsb2.readumi_per_sb2_csv_gzs),
                header_count = 1,
                out_path = "readumi_per_sb2.csv.gz"
        }
    }

    call recon_count_compute_whitelists.recon_count_compute_whitelists as recon_count_compute_whitelists {
        input:
            find_fastqs_metadata_csv = recon_count_find_fastqs.metadata_csv,
            compute_whitelists_rpsb_csv_gzs = flatten(recon_count_read_fastqs.rpsb_csv_gzs),
            r1_barcodes = r1_barcodes,
            r2_barcodes = r2_barcodes,
            memory_gb = recon_count_scatter_memory_gb,
            heap_fraction = recon_count_heap_fraction
    }

    scatter(idx in range(length(prefix_pairs))) {
        Array[String] match_whitelists_prefix_pair = prefix_pairs[idx]
        File read_fastqs_reads_df_csv_gz = recon_count_read_fastqs.reads_df_csv_gz[idx]
        File read_fastqs_metadata_csv = recon_count_read_fastqs.metadata_csv[idx]

        call recon_count_match_whitelists.recon_count_match_whitelists as recon_count_match_whitelists {
            input:
                read_fastqs_reads_df_csv_gz = read_fastqs_reads_df_csv_gz,
                read_fastqs_metadata_csv = read_fastqs_metadata_csv,
                compute_whitelists_wl_txt_gzs = recon_count_compute_whitelists.wl_txt_gzs,
                r1_filter = match_whitelists_prefix_pair[0],
                r2_filter = match_whitelists_prefix_pair[1],
                memory_gb = recon_count_scatter_memory_gb,
                heap_fraction = recon_count_heap_fraction
        }
    }

    scatter (idx in range(length(bases))) {
        String compute_chimeras_base = bases[idx]

        call recon_count_compute_chimeras.recon_count_compute_chimeras as recon_count_compute_chimeras_r1 {
            input:
                match_whitelists_reads_df_csv_gzs = recon_count_match_whitelists.reads_df_csv_gz,
                r1_filter = compute_chimeras_base,
                memory_gb = recon_count_gather_memory_gb,
                heap_fraction = recon_count_heap_fraction
        }

        call recon_count_compute_chimeras.recon_count_compute_chimeras as recon_count_compute_chimeras_r2 {
            input:
                match_whitelists_reads_df_csv_gzs = recon_count_match_whitelists.reads_df_csv_gz,
                r2_filter = compute_chimeras_base,
                memory_gb = recon_count_gather_memory_gb,
                heap_fraction = recon_count_heap_fraction
        }
    }

    Array[File] compute_chimeras_chimeric_csv_gzs = flatten(flatten([
        recon_count_compute_chimeras_r1.chimeric_csv_gz,
        recon_count_compute_chimeras_r2.chimeric_csv_gz
    ]))

    scatter(idx in range(length(prefix_pairs))) {
        Array[String] remove_chimeras_prefix_pair = prefix_pairs[idx]
        File match_whitelists_reads_df_csv_gz = recon_count_match_whitelists.reads_df_csv_gz[idx]
        File match_whitelists_metadata_csv = recon_count_match_whitelists.metadata_csv[idx]

        call recon_count_remove_chimeras.recon_count_remove_chimeras as recon_count_remove_chimeras {
            input:
                match_whitelists_reads_df_csv_gz = match_whitelists_reads_df_csv_gz,
                match_whitelists_metadata_csv = match_whitelists_metadata_csv,
                compute_chimeras_chimeric_csv_gzs = compute_chimeras_chimeric_csv_gzs,
                r1_filter = remove_chimeras_prefix_pair[0],
                r2_filter = remove_chimeras_prefix_pair[1],
                memory_gb = recon_count_scatter_memory_gb,
                heap_fraction = recon_count_heap_fraction
        }
    }

    call recon_count_count_umis.recon_count_count_umis as recon_count_count_umis {
        input:
            recon_name = validate_recon_inputs.recon_name,
            find_fastqs_filepaths_pdf = recon_count_find_fastqs.filepaths_pdf,
            compute_whitelists_elbows_pdf = recon_count_compute_whitelists.elbows_pdf,
            compute_whitelists_metadata_csv = recon_count_compute_whitelists.metadata_csv,
            remove_chimeras_reads_counts_csv_gzs = recon_count_remove_chimeras.reads_counts_csv_gz,
            remove_chimeras_umi_counts_csv_gzs = recon_count_remove_chimeras.umi_counts_csv_gz,
            remove_chimeras_umi_df_csv_gzs = recon_count_remove_chimeras.umi_df_csv_gz,
            remove_chimeras_metadata_csvs = recon_count_remove_chimeras.metadata_csv,
            read_fastqs_n_metadata_csvs = recon_count_read_fastqs_n.metadata_csv,
            downsampling_level = downsampling_level,
            r1_barcodes = r1_barcodes,
            r2_barcodes = r2_barcodes,
            memory_gb = recon_count_gather_memory_gb,
            heap_fraction = recon_count_heap_fraction
    }

    call knn.knn as knn {
        input:
            tar_suffix = "parallel",
            bcl = bcl_name,
            recon_name = validate_recon_inputs.recon_name,
            recon_count_files = flatten([
                flatten(select_all([recon_count_count_reads_rpu.reads_per_umi_csvs])),
                select_all([concat_rupsb1.out, concat_rupsb2.out]),
                recon_count_count_umis.count_umis_outputs
            ]),
            n_neighbors = n_neighbors,
            bead = bead,
            chunks = chunks,
            knn_py = knn_py,
            memory_gb = knn_memory_gb
    }

    # TODO: After testing, restore to either untarring or returning the tar
    #if (defined(local_recon_dir)) {
    #    call untar.untar as untar {
    #        input:
    #            tar_file = knn.recon_count_tar,
    #            target_directory = select_first([local_recon_dir])
    #    }
    #}

    #if (!defined(local_recon_dir)) {
        File opt_recon_count_tar = knn.recon_count_tar
    #}

    output {
        String recon_name = validate_recon_inputs.recon_name
        File qc_pdf = recon_count_count_umis.qc_pdf
        File? recon_count_tar = opt_recon_count_tar
    }
}
