# MIT License
#
# Copyright 2024 Broad Institute
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
import "../../tasks/standard_analysis/assign_cells_to_samples.wdl"
import "../../tasks/standard_analysis/create_meta_cells.wdl"
import "../../tasks/standard_analysis/detect_doublets.wdl"
import "../../tasks/standard_analysis/donor_assignment_qc.wdl"
import "../../tasks/standard_analysis/filter_dge.wdl"
import "../../tasks/standard_analysis/gather_digital_allele_counts.wdl"
import "../../tasks/standard_analysis/vcf_format_converter.wdl"

workflow dropulation {
    input {
        # required inputs
        String standard_analysis_id # <library_name>.<cell_selection_criteria_label>
        Boolean is_cbrb
        File vcf # <vcf_file>
        File vcf_idx # <vcf_file_idx>
        File sample_file # <donor_samples_file>
        Array[File] input_bams
        File raw_digital_expression_summary # <alignment_dir>/<library_name>.digital_expression_summary.txt
        File reads_per_cell_file # <alignment_dir>/<library_name>.numReads_perCell_XC_mq_10.txt.gz
        File selected_digital_expression # <standard_analysis_dir>/<standard_analysis_id>.digital_expression.txt.gz
        File selected_digital_expression_summary # <standard_analysis_dir>/<standard_analysis_id>.digital_expression_summary.txt
        File selected_cell_barcodes # <cell_selection_dir>/<standard_analysis_id>.selectedCellBarcodes.txt

        # optional inputs
        String? cell_barcode_tag # CB
        String? molecular_barcode_tag # UB
        Array[String] ignored_chromosomes = [] # ["chrX", "chrY", "chrM"]
        Array[String] locus_function_list = [] # ["INTRONIC"]
        String? strand_strategy # SENSE
        Boolean compute_cbrb_adjusted_likelihoods = true
        File? cbrb_cell_selection_report # <cbrb_dir>/<library_name>.cbrb.cell_selection_report.txt
        File? census_file
        Float? max_error_rate
        String assign_cells_to_samples_options = ""
        String detect_doublets_options = ""
    }

    if (!is_cbrb) {
        Float non_cbrb_max_error_rate = 0.01
    }

    if (defined(max_error_rate) || defined(non_cbrb_max_error_rate)) {
        Float optional_max_error_rate = select_first([max_error_rate, non_cbrb_max_error_rate])
    }

    if (basename(vcf, ".bcf") + ".bcf" != basename(vcf)) {
        call vcf_format_converter.vcf_format_converter as vcf_format_converter {
            input:
                vcf = vcf,
                vcf_idx = vcf_idx,
                bcf_path = basename(basename(vcf, ".gz"), ".vcf") + ".bcf"
        }
    }

    File bcf = select_first([vcf_format_converter.bcf, vcf])
    File bcf_idx = select_first([vcf_format_converter.bcf_idx, vcf_idx])

    if (compute_cbrb_adjusted_likelihoods) {
        scatter (idx in range(length(input_bams))) {
            call gather_digital_allele_counts.gather_digital_allele_counts as gather_digital_allele_counts {
                input:
                    alignment_bam = input_bams[idx],
                    vcf = bcf,
                    vcf_idx = bcf_idx,
                    selected_cell_barcodes = selected_cell_barcodes,
                    sample_file = sample_file,
                    cell_barcode_tag = cell_barcode_tag,
                    molecular_barcode_tag = molecular_barcode_tag,
                    ignored_chromosomes = ignored_chromosomes,
                    single_variant_reads = false,
                    multi_genes_per_read = false,
                    locus_function_list = locus_function_list,
                    strand_strategy = strand_strategy,
                    allele_frequency_output_path = standard_analysis_id + "." + idx + ".allele_freq.txt"
            }
        }

        call merge_metrics.merge_metrics as merge_gather_digital_allele_frequencies {
            input:
                merge_program = "MergeGatherDigitalAlleleFrequencies",
                input_files = gather_digital_allele_counts.allele_frequency_output,
                output_file_path = standard_analysis_id + ".allele_freq.txt",
                memory_mb = 16384,
                docker = "us.gcr.io/mccarroll-scrna-seq/drop-seq_private_java:current"
        }
    }

    scatter (idx in range(length(input_bams))) {
        call assign_cells_to_samples.assign_cells_to_samples as assign_cells_to_samples {
            input:
                input_bam = input_bams[idx],
                vcf = bcf,
                vcf_idx = bcf_idx,
                cell_bc_file = selected_cell_barcodes,
                cell_barcode_tag = cell_barcode_tag,
                molecular_barcode_tag = molecular_barcode_tag,
                ignored_chromosomes = ignored_chromosomes,
                locus_function_list = locus_function_list,
                strand_strategy = strand_strategy,
                additional_options = assign_cells_to_samples_options,
                cell_contamination_estimate_file = cbrb_cell_selection_report,
                allele_frequency_estimate_file = merge_gather_digital_allele_frequencies.output_file,
                vcf_output_path = standard_analysis_id + "." + idx + ".vcf.gz",
                output_file_path = standard_analysis_id + "." + idx + ".donor_assignments.txt"
        }

        call detect_doublets.detect_doublets as detect_doublets {
            input:
                input_bam = input_bams[idx],
                vcf = assign_cells_to_samples.vcf_output,
                vcf_idx = assign_cells_to_samples.vcf_output_idx,
                cell_bc_file = selected_cell_barcodes,
                cell_barcode_tag = cell_barcode_tag,
                molecular_barcode_tag = molecular_barcode_tag,
                single_donor_likelihood_file = assign_cells_to_samples.output_file,
                sample_file = sample_file,
                cell_contamination_estimate_file = cbrb_cell_selection_report,
                allele_frequency_estimate_file = merge_gather_digital_allele_frequencies.output_file,
                ignored_chromosomes = ignored_chromosomes,
                locus_function_list = locus_function_list,
                strand_strategy = strand_strategy,
                additional_options = detect_doublets_options,
                forced_ratio = 0.8,
                max_error_rate = optional_max_error_rate,
                output_file_path = standard_analysis_id + "." + idx + ".doublets.txt"
        }
    }

    call merge_metrics.merge_metrics as merge_cell_to_sample_assignments {
        input:
            merge_program = "MergeCellToSampleAssignments",
            input_files = assign_cells_to_samples.output_file,
            output_file_path = standard_analysis_id + ".donor_assignments.txt"
    }

    call merge_metrics.merge_metrics as merge_doublet_assignments {
        input:
            merge_program = "MergeDoubletAssignments",
            input_files = detect_doublets.output_file,
            output_file_path = standard_analysis_id + ".doublets.txt"
    }

    call donor_assignment_qc.donor_assignment_qc as donor_assignment_qc {
        input:
            doublet_likelihood_file = merge_doublet_assignments.output_file,
            dge_file = selected_digital_expression,
            dge_summary_file = selected_digital_expression_summary,
            expected_samples_file = sample_file,
            likelihood_summary_file = merge_cell_to_sample_assignments.output_file,
            dge_raw_summary_file = raw_digital_expression_summary,
            reads_per_cell_file = reads_per_cell_file,
            exp_name = standard_analysis_id,
            census_file = census_file,
            out_summary_stats_file_path = standard_analysis_id + ".dropulation_summary_stats.txt",
            out_donor_to_cell_map_path = standard_analysis_id + ".donor_cell_map.txt",
            out_cell_barcodes_file_path = standard_analysis_id + ".donorCellBarcodes.txt",
            out_file_likely_donors_path = standard_analysis_id + ".donor_list.txt",
            out_pdf_path = standard_analysis_id + ".dropulation_report.pdf",
            out_tear_sheet_pdf_path = standard_analysis_id + ".dropulation_tearsheet.pdf"
    }

    call filter_dge.filter_dge as filter_dge_donors {
        input:
            input_expression = selected_digital_expression,
            input_summary = selected_digital_expression_summary,
            donor_cell_barcodes = donor_assignment_qc.out_cell_barcodes_file,
            output_header = true,
            output_file_path = standard_analysis_id + ".donors.digital_expression.txt.gz",
            output_summary_file_path = standard_analysis_id + ".donors.digital_expression_summary.txt"
    }

    call create_meta_cells.create_meta_cells as create_meta_cells_selected {
        input:
            input_expression = selected_digital_expression,
            donor_cell_map = donor_assignment_qc.out_donor_to_cell_map,
            output_file_path = standard_analysis_id + ".meta_cell.expression.txt",
            metrics_file_path = standard_analysis_id + ".meta_cell_metrics"
    }

    output {
        File donor_assignments = merge_cell_to_sample_assignments.output_file
        File doublet_assignments = merge_doublet_assignments.output_file
        File summary_stats = donor_assignment_qc.out_summary_stats_file
        File donor_cell_map = donor_assignment_qc.out_donor_to_cell_map
        File donor_cell_barcodes = donor_assignment_qc.out_cell_barcodes_file
        File likely_donors = donor_assignment_qc.out_file_likely_donors
        File dropulation_report_pdf = donor_assignment_qc.out_pdf
        File dropulation_tear_sheet_pdf = donor_assignment_qc.out_tear_sheet_pdf
        File donors_digital_expression = filter_dge_donors.output_file
        File donors_digital_expression_summary = filter_dge_donors.output_summary_file
        File meta_cell_expression = create_meta_cells_selected.output_file
        File meta_cell_metrics = select_first([create_meta_cells_selected.metrics_file])
        File? digital_allele_frequencies = merge_gather_digital_allele_frequencies.output_file
    }
}
