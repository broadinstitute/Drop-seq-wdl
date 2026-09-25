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

import "../../tasks/bcl_to_fastqs/bcl_convert.wdl"
import "../../tasks/bcl_to_fastqs/find_barcode_orientation.wdl"
import "../../tasks/bcl_to_fastqs/list_barcode_samples.wdl"
import "../../tasks/bcl_to_fastqs/list_sample_fastqs.wdl"
import "../../tasks/bcl_to_fastqs/make_sample_sheet.wdl"
import "../../tasks/bcl_to_fastqs/write_fofn.wdl"
import "../../tasks/common/copy_file.wdl"

workflow bcl_to_fastqs {
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
        Array[Int] bcl_convert_lanes = [1, 2, 3, 4, 5, 6, 7, 8]
        Boolean bcl_only_matched_reads = false
        Boolean first_tile_only = false
        Boolean? reverse_complement_index_barcode_1
        Boolean? reverse_complement_index_barcode_2
    }

    String bcl_or_barcodes_name =
        if defined(bcl) then select_first([bcl]) else basename(basename(barcodes_tsv, ".tsv"), ".txt")
    String fastq_dir =
        if defined(local_fastq_dir) then select_first([local_fastq_dir]) + "/" + bcl_or_barcodes_name else "fastq"

    if (!defined(reverse_complement_index_barcode_1) || !defined(reverse_complement_index_barcode_2)) {

        # Determine the best index barcode orientations by trying all 4 combinations
        Array[Boolean] orientation_rcib1s = [true, true, false, false]
        Array[Boolean] orientation_rcib2s = [false, true, false, true]

        scatter (orientation_idx in range(length(orientation_rcib1s))) {
            Boolean orientation_rcib1 = orientation_rcib1s[orientation_idx]
            Boolean orientation_rcib2 = orientation_rcib2s[orientation_idx]
            String orientation_tag =
                "rcib1_" + (if orientation_rcib1 then "true" else "false") + "." +
                "rcib2_" + (if orientation_rcib2 then "true" else "false")

            call make_sample_sheet.make_sample_sheet as make_sample_sheet_orientation {
                input:
                    sample_sheet_path = orientation_tag + ".SampleSheet.csv",
                    barcodes_tsv = barcodes_tsv,
                    reverse_complement_index_barcode_1 = orientation_rcib1,
                    reverse_complement_index_barcode_2 = orientation_rcib2
            }

            if (length(bcl_lane_tars) > 0) {
                File bcl_lane_tar_orientation = bcl_lane_tars[0]
            }

            call bcl_convert.bcl_convert as bcl_convert_orientation {
                input:
                    sample_sheet = make_sample_sheet_orientation.sample_sheet,
                    input_dir = bcl_dir,
                    output_dir = orientation_tag + ".fastq",
                    docker = bcl_convert_docker,
                    input_tars = select_all([bcl_input_tar, bcl_lane_tar_orientation]),
                    bcl_only_lane = bcl_convert_lanes[0],
                    bcl_only_matched_reads = false,
                    first_tile_only = true
            }
        }

        call find_barcode_orientation.find_barcode_orientation as find_barcode_orientation {
            input:
                demultiplex_stats = bcl_convert_orientation.demultiplex_stats,
                reverse_complement_index_barcode_1s = orientation_rcib1s,
                reverse_complement_index_barcode_2s = orientation_rcib2s
        }
    }

    Boolean rcib1_selected = select_first([
        reverse_complement_index_barcode_1,
        find_barcode_orientation.reverse_complement_index_barcode_1
    ])
    Boolean rcib2_selected = select_first([
        reverse_complement_index_barcode_2,
        find_barcode_orientation.reverse_complement_index_barcode_2
    ])

    call make_sample_sheet.make_sample_sheet as make_sample_sheet {
        input:
            barcodes_tsv = barcodes_tsv,
            sample_sheet_path = fastq_dir + "/SampleSheet.csv",
            reverse_complement_index_barcode_1 = rcib1_selected,
            reverse_complement_index_barcode_2 = rcib2_selected,
    }

    scatter (idx in range(length(bcl_convert_lanes))) {
        Int lane = bcl_convert_lanes[idx]
        if (length(bcl_lane_tars) > 0) {
            File bcl_lane_tar = bcl_lane_tars[idx]
        }

        call bcl_convert.bcl_convert as bcl_convert {
            input:
                sample_sheet = make_sample_sheet.sample_sheet,
                input_dir = bcl_dir,
                output_dir = fastq_dir + "/" + lane,
                docker = bcl_convert_docker,
                input_tars = select_all([bcl_input_tar, bcl_lane_tar]),
                bcl_only_lane = lane,
                bcl_only_matched_reads = bcl_only_matched_reads,
                first_tile_only = first_tile_only,
                bcl_sampleproject_subdirectories = true
        }

        Array[String] lane_fastqs =
            if defined(local_fastq_dir) then bcl_convert.local_fastqs else bcl_convert.glob_fastqs
    }

    Array[String] all_fastqs = flatten(lane_fastqs)

    if (!defined(local_fastq_dir)) {
        Array[File] glob_fastqs = flatten(bcl_convert.glob_fastqs)
    }

    call write_fofn.write_fofn as write_all_fastqs {
        input:
            file_paths = all_fastqs,
            fofn_path = bcl_or_barcodes_name + ".fastqs.txt"
    }

    call list_barcode_samples.list_barcode_samples as list_barcode_samples {
        input:
            barcodes_tsv = barcodes_tsv,
            output_prefix = bcl_or_barcodes_name
    }

    scatter (sample_idx in range(length(list_barcode_samples.sample_names))) {
        String sample_name = list_barcode_samples.sample_names[sample_idx]

        call list_sample_fastqs.list_sample_fastqs as list_sample_fastqs {
            input:
                all_fastqs = all_fastqs,
                sample_name = sample_name,
                barcodes_tsv = barcodes_tsv,
                lanes = bcl_convert_lanes
        }

        call write_fofn.write_fofn as write_sample_fastqs {
            input:
                file_paths = list_sample_fastqs.sample_fastqs,
                fofn_path = sample_name + ".fastqs.txt"
        }

        if (defined(local_fastq_dir)) {
            call copy_file.copy_file as copy_file_sample_fastqs {
                input:
                    input_file = write_sample_fastqs.fofn,
                    out_path = fastq_dir + "/" + sample_name + ".fastqs.txt"
            }
        }
    }

    # While we're using retrieve_cromwell_results.py, uniquify the report file names.
    # May or may not be necessary in the future.
    if (!defined(local_fastq_dir)) {
        scatter (idx in range(length(bcl_convert_lanes))) {
            Int lane = bcl_convert_lanes[idx]
            call copy_file.copy_file as copy_file_demultiplex_stats {
                input:
                    input_file = bcl_convert.demultiplex_stats[idx],
                    out_path = "Demultiplex_Stats." + lane + ".csv"
            }
            call copy_file.copy_file as copy_file_index_hopping_counts {
                input:
                    input_file = bcl_convert.index_hopping_counts[idx],
                    out_path = "Index_Hopping_Counts." + lane + ".csv"
            }
            call copy_file.copy_file as copy_file_top_unknown_barcodes {
                input:
                    input_file = bcl_convert.top_unknown_barcodes[idx],
                    out_path = "Top_Unknown_Barcodes." + lane + ".csv"
            }
        }
    }

    output {
        String bcl_name = bcl_or_barcodes_name
        File fastqs_file = write_all_fastqs.fofn
        File sample_ids_file = list_barcode_samples.sample_ids_file
        File sample_names_file = list_barcode_samples.sample_names_file
        Array[String] sample_ids = list_barcode_samples.sample_ids
        Array[String] sample_names = list_barcode_samples.sample_names
        Array[Array[String]] sample_fastqs = list_sample_fastqs.sample_fastqs
        Array[File] sample_fastqs_files = write_sample_fastqs.fofn
        Array[File]? fastqs = glob_fastqs
        Array[File]? demultiplex_stats = copy_file_demultiplex_stats.out
        Array[File]? index_hopping_counts = copy_file_index_hopping_counts.out
        Array[File]? top_unknown_barcodes = copy_file_top_unknown_barcodes.out
    }
}
