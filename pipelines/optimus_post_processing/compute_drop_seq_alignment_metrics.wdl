# MIT License
#
# Copyright 2025 Broad Institute
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

import "../../tasks/common/merge_metrics.wdl"
import "../../tasks/optimus_post_processing/bam_tag_histogram.wdl"
import "../../tasks/optimus_post_processing/base_distribution_at_read_position.wdl"
import "../../tasks/optimus_post_processing/collect_rna_seq_metrics.wdl"
import "../../tasks/optimus_post_processing/gather_read_quality_metrics.wdl"
import "../../tasks/optimus_post_processing/mean_quality_by_cycle.wdl"
import "../../tasks/optimus_post_processing/merge_mean_quality_by_cycle.wdl"

workflow compute_drop_seq_alignment_metrics {
    input {
        # required inputs
        String library_name # v123_10X-GEX-3P_abc_rxn8
        Array[File] input_bams
        File ref_flat

        # optional inputs
        File? ribosomal_intervals
        # Leaving these empty triggers other behavior in the tasks.
        # Therefore we always default them to the DropSeq defaults
        # even if they will be overriden for Optimus processing.
        String cell_barcode_tag = "XC" # CB
        String molecular_barcode_tag = "XM" # UB
        Boolean do_read_quality_metrics = true
    }

    Int read_quality_for_get_num_reads_per_cell_barcode = 10
    String reads_per_cell_barcode_ext = ".numReads_perCell_" + cell_barcode_tag +
        "_mq_" + read_quality_for_get_num_reads_per_cell_barcode + ".txt.gz"

    scatter (idx in range(length(input_bams))) {
        File input_bam = input_bams[idx]
        String input_bam_name = basename(input_bam, ".bam")

        call collect_rna_seq_metrics.collect_rna_seq_metrics as collect_rna_seq_metrics {
            input:
                input_bam = input_bam,
                ref_flat = ref_flat,
                strand_specificity = "NONE",
                ribosomal_intervals = ribosomal_intervals,
                output_file_path = input_bam_name + ".fracIntronicExonic.txt"
        }

        call gather_read_quality_metrics.gather_read_quality_metrics as gather_read_quality_metrics_by_cell {
            input:
                input_bam = input_bam,
                tag = cell_barcode_tag,
                output_file_path = input_bam_name + ".ReadQualityMetricsByCell.txt.gz"
        }

        call mean_quality_by_cycle.mean_quality_by_cycle as mean_quality_by_cycle_all_reads {
            input:
                input_bam = input_bam,
                aligned_reads_only = false,
                output_metrics_path = input_bam_name + ".meanQualityPerCycle_allReads.txt"
        }

        call mean_quality_by_cycle.mean_quality_by_cycle as mean_quality_by_cycle_aligned_reads {
            input:
                input_bam = input_bam,
                aligned_reads_only = true,
                output_metrics_path = input_bam_name + ".meanQualityPerCycle_alignedReads.txt"
        }

        call bam_tag_histogram.bam_tag_histogram as bam_tag_histogram_num_reads_per_cell_barcode {
            input:
                input_bam = input_bam,
                tag = cell_barcode_tag,
                read_mq = read_quality_for_get_num_reads_per_cell_barcode,
                output_file_path = input_bam_name + reads_per_cell_barcode_ext
        }

        call base_distribution_at_read_position.base_distribution_at_read_position
            as base_distribution_at_read_position_cellular {
            input:
                input_bam = input_bam,
                tag = cell_barcode_tag,
                output_file_path = input_bam_name + ".barcode_distribution_" + cell_barcode_tag + ".txt"
        }

        call base_distribution_at_read_position.base_distribution_at_read_position
            as base_distribution_at_read_position_molecular {
            input:
                input_bam = input_bam,
                tag = molecular_barcode_tag,
                output_file_path = input_bam_name + ".barcode_distribution_" + molecular_barcode_tag + ".txt"
        }

        if (do_read_quality_metrics) {
            call gather_read_quality_metrics.gather_read_quality_metrics as gather_read_quality_metrics {
                input:
                    input_bam = input_bam,
                    output_file_path = input_bam_name + ".ReadQualityMetrics.txt"
            }
        }
    }

    call merge_metrics.merge_metrics as merge_rna_seq_metrics {
        input:
            merge_program = "MergeRnaSeqMetrics",
            input_files = collect_rna_seq_metrics.output_file,
            output_file_path = library_name + ".fracIntronicExonic.txt"
    }

    call merge_metrics.merge_metrics as merge_read_quality_by_cell_metrics {
        input:
            merge_program = "MergeReadQualityMetrics",
            input_files = gather_read_quality_metrics_by_cell.output_file,
            output_file_path = library_name + ".ReadQualityMetricsByCell.txt.gz"
    }

    if (do_read_quality_metrics) {
        call merge_metrics.merge_metrics as merge_read_quality_metrics {
            input:
                merge_program = "MergeReadQualityMetrics",
                input_files = select_all(gather_read_quality_metrics.output_file),
                output_file_path = library_name + ".ReadQualityMetrics.txt"
        }
    }

    call merge_mean_quality_by_cycle.merge_mean_quality_by_cycle as merge_mean_quality_by_cycle_all {
        input:
            input_files = mean_quality_by_cycle_all_reads.output_metrics,
            output_metrics_path = library_name + ".meanQualityPerCycle_allReads.txt",
            output_chart_path = library_name + ".meanQualityPerCycle_allReads.pdf"
    }

    call merge_mean_quality_by_cycle.merge_mean_quality_by_cycle as merge_mean_quality_by_cycle_aligned {
        input:
            input_files = mean_quality_by_cycle_aligned_reads.output_metrics,
            output_metrics_path = library_name + ".meanQualityPerCycle_alignedReads.txt",
            output_chart_path = library_name + ".meanQualityPerCycle_alignedReads.pdf"
    }

    call merge_metrics.merge_metrics as merge_num_reads_per_cell_barcode {
        input:
            merge_program = "MergeBamTagHistograms",
            input_files = bam_tag_histogram_num_reads_per_cell_barcode.output_file,
            output_file_path = library_name + reads_per_cell_barcode_ext
    }

    call merge_metrics.merge_metrics as merge_base_distribution_at_read_position_cellular {
        input:
            merge_program = "MergeBaseDistributionAtReadPosition",
            input_files = base_distribution_at_read_position_cellular.output_file,
            output_file_path = library_name + ".barcode_distribution_" + cell_barcode_tag + ".txt"
    }

    call merge_metrics.merge_metrics as merge_base_distribution_at_read_position_molecular {
        input:
            merge_program = "MergeBaseDistributionAtReadPosition",
            input_files = base_distribution_at_read_position_molecular.output_file,
            output_file_path = library_name + ".barcode_distribution_" + molecular_barcode_tag + ".txt"
    }

    output {
        File rna_seq_metrics = merge_rna_seq_metrics.output_file
        File read_quality_by_cell_metrics = merge_read_quality_by_cell_metrics.output_file
        File mean_quality_by_cycle_all_metrics = merge_mean_quality_by_cycle_all.output_metrics
        File mean_quality_by_cycle_all_chart = select_first([merge_mean_quality_by_cycle_all.output_chart])
        File mean_quality_by_cycle_aligned_metrics = merge_mean_quality_by_cycle_aligned.output_metrics
        File mean_quality_by_cycle_aligned_chart = select_first([merge_mean_quality_by_cycle_aligned.output_chart])
        File num_reads_per_cell_barcode = merge_num_reads_per_cell_barcode.output_file
        File base_distribution_at_read_position_cellular = merge_base_distribution_at_read_position_cellular.output_file
        File base_distribution_at_read_position_molecular =
            merge_base_distribution_at_read_position_molecular.output_file
        File? read_quality_metrics = merge_read_quality_metrics.output_file
    }
}
