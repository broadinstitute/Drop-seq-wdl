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

import "discover_gene_meta_genes.wdl"
import "dropulation.wdl"
import "../../tasks/common/merge_metrics.wdl"
import "../../tasks/standard_analysis/call_sex_from_metacells.wdl"
import "../../tasks/standard_analysis/chimeric_report_edit_distance_collapse.wdl"
import "../../tasks/standard_analysis/create_meta_cells.wdl"
import "../../tasks/standard_analysis/downsample_transcripts_and_quantiles.wdl"
import "../../tasks/standard_analysis/filter_dge.wdl"
import "../../tasks/standard_analysis/gather_umi_read_intervals.wdl"
import "../../tasks/standard_analysis/merge_umi_read_intervals.wdl"
import "../../tasks/standard_analysis/plot_standard_analysis_organism.wdl"
import "../../tasks/standard_analysis/validate_aligned_sam.wdl"

workflow standard_analysis {
    input {
        # required inputs
        String library_name # v123_10X-GEX-3P_abc_rxn8
        String cell_selection_criteria_label # umi_500-Inf_intronic_0.550-1.000_10X
        Array[File] input_bams
        File input_digital_expression # <cbrb_dir>/<library_name>.cbrb.digital_expression.txt.gz
        File raw_digital_expression # <alignment_dir>/<library_name>.digital_expression.txt.gz
        File raw_digital_expression_summary # <alignment_dir>/<library_name>.digital_expression_summary.txt
        File chimeric_transcripts # <alignment_dir>/<library_name>.chimeric_transcripts.txt.gz
        File reads_per_cell_file # <alignment_dir>/<library_name>.numReads_perCell_XC_mq_10.txt.gz
        File selected_cell_barcodes # <cell_selection_dir>/<standard_analysis_id>.selectedCellBarcodes.txt
        Boolean do_discover_meta_genes
        Boolean is_cbrb

        # optional inputs
        File? vcf # <vcf_file>
        File? vcf_idx # <vcf_file_idx>
        File? sample_file # <donor_samples_file>
        String? cell_barcode_tag # CB
        String? molecular_barcode_tag # UB
        Array[String] ignored_chromosomes = [] # ["chrX", "chrY", "chrM"]
        Array[String] locus_function_list = [] # ["INTRONIC"]
        String? strand_strategy # SENSE
        Boolean compute_cbrb_adjusted_likelihoods = true
        File? cbrb_cell_selection_report # <cbrb_dir>/<library_name>.cbrb.cell_selection_report.txt
        File? ambient_cell_barcodes # <cell_selection_dir>/<standard_analysis_id>.ambient.cellBarcodes.txt
        File? sex_caller_config_yaml_file # <sex_caller_config_yaml_file>
        File? census_file
        Float? max_error_rate
        String assign_cells_to_samples_options = ""
        String detect_doublets_options = ""
        String? non_dropulation_donor
    }

    String standard_analysis_id = library_name + "." + cell_selection_criteria_label
    Boolean do_dropulation = defined(vcf) && defined(vcf_idx) && defined(sample_file)
    Boolean do_non_dropulation_metacell = !do_dropulation && defined(non_dropulation_donor)
    Boolean has_metacell = do_dropulation || do_non_dropulation_metacell
    Boolean do_call_sex = has_metacell && defined(sex_caller_config_yaml_file)

    call validate_aligned_sam.validate_aligned_sam as validate_aligned_sam {
        input:
            input_bams = input_bams,
            check_contains_paired_reads = false
    }

    call filter_dge.filter_dge as filter_dge_selected {
        input:
            input_expression = input_digital_expression,
            input_summary = raw_digital_expression_summary,
            donor_cell_barcodes = selected_cell_barcodes,
            output_header = true,
            output_file_path = standard_analysis_id + ".digital_expression.txt.gz",
            output_summary_file_path = standard_analysis_id + ".digital_expression_summary.txt"
    }

    scatter (idx in range(length(input_bams))) {
        call gather_umi_read_intervals.gather_umi_read_intervals as gather_umi_read_intervals {
            input:
                alignment_bam = input_bams[idx],
                selected_cell_barcodes = selected_cell_barcodes,
                locus_function_list = locus_function_list,
                strand_strategy = strand_strategy,
                output_file_path = library_name + "." + idx + ".umi_read_intervals.tsv.gz"
        }
    }

    call merge_umi_read_intervals.merge_umi_read_intervals as merge_umi_read_intervals {
        input:
            input_files = gather_umi_read_intervals.output_file,
            output_file_path = library_name + ".umi_read_intervals.tsv.gz"
    }

    if (defined(ambient_cell_barcodes)) {
        call filter_dge.filter_dge as filter_dge_ambient {
            input:
                input_expression = raw_digital_expression,
                input_summary = raw_digital_expression_summary,
                donor_cell_barcodes = select_first([ambient_cell_barcodes]),
                output_header = true,
                output_file_path = standard_analysis_id + ".ambient.digital_expression.txt.gz",
                output_summary_file_path = standard_analysis_id + ".ambient.digital_expression_summary.txt"
        }

        call create_meta_cells.create_meta_cells as create_meta_cells_ambient {
            input:
                input_expression = filter_dge_ambient.output_file,
                output_file_path = standard_analysis_id + ".ambient.metacells.txt",
                single_metacell_label = "ambient"
        }
    }

    call chimeric_report_edit_distance_collapse.chimeric_report_edit_distance_collapse as chimeric_report_edit_distance_collapse {
        input:
            chimeric_transcripts = chimeric_transcripts,
            selected_cell_barcodes = selected_cell_barcodes,
            ignore_chimeric = true,
            output_file_path = standard_analysis_id + ".molBC.txt.gz"
    }

    call downsample_transcripts_and_quantiles.downsample_transcripts_and_quantiles as downsample_transcripts_and_quantiles {
        input:
            molecular_barcode_distribution_by_gene = chimeric_report_edit_distance_collapse.output_file,
            selected_cell_barcodes = selected_cell_barcodes,
            output_downsampling_file_path = standard_analysis_id + ".transcript_downsampling.txt",
            output_quantile_file_path = standard_analysis_id + ".transcript_downsampling_deciles.txt"
    }

    if (do_dropulation) {
        call dropulation.dropulation as dropulation {
            input:
                standard_analysis_id = standard_analysis_id,
                is_cbrb = is_cbrb,
                vcf = select_first([vcf]),
                vcf_idx = select_first([vcf_idx]),
                sample_file = select_first([sample_file]),
                input_bams = input_bams,
                raw_digital_expression_summary = raw_digital_expression_summary,
                reads_per_cell_file = reads_per_cell_file,
                selected_digital_expression = filter_dge_selected.output_file,
                selected_digital_expression_summary = filter_dge_selected.output_summary_file,
                selected_cell_barcodes = selected_cell_barcodes,
                cell_barcode_tag = cell_barcode_tag,
                molecular_barcode_tag = molecular_barcode_tag,
                locus_function_list = locus_function_list,
                compute_cbrb_adjusted_likelihoods = compute_cbrb_adjusted_likelihoods,
                cbrb_cell_selection_report = cbrb_cell_selection_report,
                max_error_rate = max_error_rate,
                assign_cells_to_samples_options = assign_cells_to_samples_options,
                detect_doublets_options = detect_doublets_options,
                strand_strategy = strand_strategy,
                ignored_chromosomes = ignored_chromosomes,
                census_file = census_file
        }
    }

    if (do_non_dropulation_metacell) {
        call create_meta_cells.create_meta_cells as create_meta_cells_non_dropulation {
            input:
                input_expression = filter_dge_selected.output_file,
                single_metacell_label = non_dropulation_donor,
                output_file_path = standard_analysis_id + ".meta_cell.expression.txt",
                metrics_file_path = standard_analysis_id + ".meta_cell_metrics"
        }
    }

    if (has_metacell) {
        File optional_meta_cell_expression = select_first([
            dropulation.meta_cell_expression,
            create_meta_cells_non_dropulation.output_file
        ])
        File optional_meta_cell_metrics = select_first([
            dropulation.meta_cell_metrics,
            create_meta_cells_non_dropulation.metrics_file
        ])
    }

    if (do_call_sex) {
        call call_sex_from_metacells.call_sex_from_metacells as call_sex_from_metacells {
            input:
                analysis_identifier = standard_analysis_id,
                sex_caller_config_yaml_file = select_first([sex_caller_config_yaml_file]),
                input_metacell_file = select_first([optional_meta_cell_expression]),
                input_metacell_metrics_file = select_first([optional_meta_cell_metrics]),
                output_sex_call_file_path = standard_analysis_id + ".sex.txt",
                output_hist_pdf_file_path = standard_analysis_id + ".sex.pdf"
        }
    }

    if (do_discover_meta_genes) {
        call discover_gene_meta_genes.discover_gene_meta_genes as discover_gene_meta_genes {
            input:
                library_name = library_name,
                standard_analysis_id = standard_analysis_id,
                selected_digital_expression = filter_dge_selected.output_file,
                selected_digital_expression_summary = filter_dge_selected.output_summary_file,
                input_bams = input_bams,
                selected_cell_barcodes = selected_cell_barcodes,
                locus_function_list = locus_function_list,
                strand_strategy = strand_strategy,
                ignored_chromosomes = ignored_chromosomes
        }
    }

    if (do_discover_meta_genes && do_dropulation) {
        call filter_dge.filter_dge as filter_dge_gmg_donors {
            input:
                input_expression = select_first([discover_gene_meta_genes.gmg_digital_expression]),
                input_summary = select_first([discover_gene_meta_genes.gmg_digital_expression_summary]),
                donor_cell_barcodes = select_first([dropulation.donor_cell_barcodes]),
                output_header = true,
                output_file_path = standard_analysis_id + ".gmg.donors.digital_expression.txt.gz",
                output_summary_file_path = standard_analysis_id + ".gmg.donors.digital_expression_summary.txt"
        }
    }

    call plot_standard_analysis_organism.plot_standard_analysis_single_organism as plot_standard_analysis_organism {
        input:
            transcript_quantile_file = downsample_transcripts_and_quantiles.output_quantile_file,
            transcript_downsampling_file = downsample_transcripts_and_quantiles.output_downsampling_file,
            molecular_barcode_distribution_by_gene_file = chimeric_report_edit_distance_collapse.output_file,
            digital_expression_summary_file = filter_dge_selected.output_summary_file,
            out_plot_path = standard_analysis_id + ".pdf"
    }

    output {
        File selected_digital_expression = filter_dge_selected.output_file
        File selected_digital_expression_summary = filter_dge_selected.output_summary_file
        File umi_read_intervals = merge_umi_read_intervals.output_file
        File chimeric_transcripts_collapsed = chimeric_report_edit_distance_collapse.output_file
        File transcript_downsampling = downsample_transcripts_and_quantiles.output_downsampling_file
        File transcript_downsampling_deciles = downsample_transcripts_and_quantiles.output_quantile_file
        File transcript_downsampling_pdf = plot_standard_analysis_organism.out_plot
        File transcript_downsampling_summary = plot_standard_analysis_organism.transcript_downsampling_summary
        File? ambient_digital_expression = filter_dge_ambient.output_file
        File? ambient_digital_expression_summary = filter_dge_ambient.output_summary_file
        File? ambient_metacells = create_meta_cells_ambient.output_file
        File? digital_allele_frequencies = dropulation.digital_allele_frequencies
        File? donor_assignments = dropulation.donor_assignments
        File? doublet_assignments = dropulation.doublet_assignments
        File? summary_stats = dropulation.summary_stats
        File? donor_cell_map = dropulation.donor_cell_map
        File? donor_cell_barcodes = dropulation.donor_cell_barcodes
        File? likely_donors = dropulation.likely_donors
        File? dropulation_report_pdf = dropulation.dropulation_report_pdf
        File? dropulation_tear_sheet_pdf = dropulation.dropulation_tear_sheet_pdf
        File? donors_digital_expression = dropulation.donors_digital_expression
        File? donors_digital_expression_summary = dropulation.donors_digital_expression_summary
        File? meta_cell_expression = optional_meta_cell_expression
        File? meta_cell_metrics = optional_meta_cell_metrics
        File? sex_calls = call_sex_from_metacells.output_sex_call_file
        File? sex_calls_pdf = call_sex_from_metacells.output_hist_pdf_file
        File? metagene_report = discover_gene_meta_genes.metagene_report
        File? metagene_digital_expression = discover_gene_meta_genes.metagene_digital_expression
        File? metagene_digital_expression_summary = discover_gene_meta_genes.metagene_digital_expression_summary
        File? gmg_digital_expression = discover_gene_meta_genes.gmg_digital_expression
        File? gmg_digital_expression_summary = discover_gene_meta_genes.gmg_digital_expression_summary
        File? gmg_donors_digital_expression = filter_dge_gmg_donors.output_file
        File? gmg_donors_digital_expression_summary = filter_dge_gmg_donors.output_summary_file
    }
}
