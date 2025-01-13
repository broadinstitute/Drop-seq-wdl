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

import "../../tasks/common/merge_dge.wdl"
import "../../tasks/common/merge_metrics.wdl"
import "../../tasks/common/merge_split_dges.wdl"
import "../../tasks/standard_analysis/digital_expression.wdl"
import "../../tasks/standard_analysis/discover_meta_genes.wdl"

workflow discover_gene_meta_genes {
    input {
        # required inputs
        String library_name # v123_10X-GEX-3P_abc_rxn8
        String standard_analysis_id # <library_name>.<cell_selection_criteria_label>
        File selected_digital_expression # <standard_analysis_dir>/<standard_analysis_id>.digital_expression.txt.gz
        File selected_digital_expression_summary # <standard_analysis_dir>/<standard_analysis_id>.digital_expression_summary.txt
        Array[File] input_bams
        File selected_cell_barcodes # <cell_selection_dir>/<standard_analysis_id>.selectedCellBarcodes.txt

        # optional inputs
        String? cell_barcode_tag # CB
        String? molecular_barcode_tag # UB
        String gmg_gene_name_tag = "mn"
        String gmg_gene_strand_tag = "ms"
        String gmg_gene_function_tag = "mf"
        Array[String] locus_function_list = [] # ["INTRONIC"]
        String? strand_strategy # SENSE
    }

    scatter (idx in range(length(input_bams))) {
        call discover_meta_genes.discover_meta_genes as discover_meta_genes_part_1 {
            input:
                alignment_bam = input_bams[idx],
                selected_cell_barcodes = selected_cell_barcodes,
                write_single_genes = true,
                cell_barcode_tag = cell_barcode_tag,
                molecular_barcode_tag = molecular_barcode_tag,
                metagene_name = gmg_gene_name_tag,
                metagene_strand = gmg_gene_strand_tag,
                metagene_function = gmg_gene_function_tag,
                locus_function_list = locus_function_list,
                report_file_path = standard_analysis_id + "." + idx + ".metagene_report.txt"
        }
    }

    call merge_metrics.merge_metrics as merge_meta_gene_reports {
        input:
            merge_program = "MergeMetaGeneReports",
            input_files = select_all(discover_meta_genes_part_1.report_file),
            output_file_path = standard_analysis_id + ".metagene_report.txt"
    }

    scatter (idx in range(length(input_bams))) {
        call discover_meta_genes.discover_meta_genes as discover_meta_genes_part_2 {
            input:
                alignment_bam = input_bams[idx],
                selected_cell_barcodes = selected_cell_barcodes,
                write_single_genes = false,
                cell_barcode_tag = cell_barcode_tag,
                molecular_barcode_tag = molecular_barcode_tag,
                metagene_name = gmg_gene_name_tag,
                metagene_strand = gmg_gene_strand_tag,
                metagene_function = gmg_gene_function_tag,
                locus_function_list = locus_function_list,
                known_meta_gene_file = merge_meta_gene_reports.output_file,
                output_bam_path = standard_analysis_id + "." + idx + ".metagene.bam"
        }

        call digital_expression.digital_expression as digital_expression {
            input:
                metagene_bam = select_first([discover_meta_genes_part_2.output_bam]),
                selected_cell_barcodes = selected_cell_barcodes,
                edit_distance = 1,
                read_mq = 0,
                min_bc_read_threshold = 0,
                output_header = true,
                omit_missing_cells = true,
                unique_experiment_id = library_name,
                gene_name_tag = gmg_gene_name_tag,
                gene_strand_tag = gmg_gene_strand_tag,
                gene_function_tag = gmg_gene_function_tag,
                strand_strategy = strand_strategy,
                locus_function_list = locus_function_list,
                output_file_path = standard_analysis_id + ".metagene.digital_expression.txt.gz",
                summary_file_path = standard_analysis_id + ".metagene.digital_expression_summary.txt"
        }
    }

    call merge_split_dges.merge_split_dges as merge_split_dges {
        input:
            input_expression = digital_expression.output_file,
            output_file_path = standard_analysis_id + ".metagene.digital_expression.txt.gz"
    }

    call merge_metrics.merge_metrics as merge_dge_summaries {
        input:
            merge_program = "MergeDgeSummaries",
            other_args = "--ACCUMULATE_CELL_BARCODE_METRICS true",
            input_files = digital_expression.summary_file,
            output_file_path = standard_analysis_id + ".metagene.digital_expression_summary.txt"
    }

    call merge_dge.merge_dge as merge_dge_gmg {
        input:
            input_expression = [selected_digital_expression, merge_split_dges.output_file],
            header_stringency = "LENIENT",
            output_file_path = standard_analysis_id + ".gmg.digital_expression.txt.gz"
    }

    call merge_metrics.merge_metrics as merge_dge_gmg_summaries {
        input:
            merge_program = "MergeDgeSummaries",
            other_args = "--ACCUMULATE_CELL_BARCODE_METRICS true",
            input_files = [selected_digital_expression_summary, merge_dge_summaries.output_file],
            output_file_path = standard_analysis_id + ".gmg.digital_expression_summary.txt"
    }

    output {
        File metagene_report = merge_meta_gene_reports.output_file
        File metagene_digital_expression = merge_split_dges.output_file
        File metagene_digital_expression_summary = merge_dge_summaries.output_file
        File gmg_digital_expression = merge_dge_gmg.output_file
        File gmg_digital_expression_summary = merge_dge_gmg_summaries.output_file
    }
}
