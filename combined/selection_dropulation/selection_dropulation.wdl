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

import "../../pipelines/cell_classification/cell_classification.wdl"
import "../../pipelines/cell_selection/cell_selection.wdl"
import "../../pipelines/standard_analysis/standard_analysis.wdl"

workflow selection_dropulation {
    input {
        # required inputs
        String library_name # v123_10X-GEX-3P_abc_rxn8
        File cell_selection_report # <alignment_dir>/<library_name>.cell_selection_report.txt
        File read_quality_metrics # <alignment_dir>/<library_name>.ReadQualityMetrics.txt
        Array[File] input_bams
        File input_digital_expression # <cbrb_dir>/<library_name>.cbrb.digital_expression.txt.gz
        File raw_digital_expression # <alignment_dir>/<library_name>.digital_expression.txt.gz
        File raw_digital_expression_summary # <alignment_dir>/<library_name>.digital_expression_summary.txt
        File chimeric_transcripts # <alignment_dir>/<library_name>.chimeric_transcripts.txt.gz
        File reads_per_cell_file # <alignment_dir>/<library_name>.numReads_perCell_XC_mq_10.txt.gz
        Boolean do_discover_meta_genes
        Boolean is_cbrb

        # optional inputs
        Int? min_umis_per_cell # 500
        Int? max_umis_per_cell
        Int? max_rbmt_per_cell
        Float? min_intronic_per_cell # 0.55
        Float? max_intronic_per_cell
        Float? efficiency_threshold_log10
        String? call_stamps_method # svm_nuclei
        File? mtx # matrix.mtx.gz
        File? features # features.tsv.gz
        File? barcodes # barcodes.tsv.gz
        Boolean is_10x = true
        File? cbrb_non_empties # <cbrb_dir>/<library_name>.cbrb.selectedCellBarcodes.txt
        File? cbrb_num_transcripts # <cbrb_dir>/<library_name>.cbrb.num_transcripts.txt
        File? chimeric_read_metrics_file # <alignment_dir>/<library_name>.chimeric_read_metrics
        Array[File] barcode_metrics_files = []
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
        File? sex_caller_config_yaml_file # <sex_caller_config_yaml_file>
        File? census_file
        Float? max_error_rate
        String assign_cells_to_samples_options = ""
        String detect_doublets_options = ""
        String? non_dropulation_donor
        File? cell_classification_models_tar # <cell_classification_models_dir>.tar
        String? sc_pred_model_name #: "caudate"
        Array[Float] doublet_finder_pns = [0.4, 0.45, 0.5]
        Array[Float] doublet_finder_pks = []
        Array[Int] doublet_finder_num_pcs = []
        String? cbrb_analysis_tag # auto
        File? selected_cell_barcode_file # optional
        File? donor_state_file # optional
        Boolean do_create_metacells_by_cell_type = false
    }

    call cell_selection.cell_selection as cell_selection {
        input:
            library_name = library_name,
            cell_selection_report = cell_selection_report,
            read_quality_metrics = read_quality_metrics,
            min_umis_per_cell = min_umis_per_cell,
            max_umis_per_cell = max_umis_per_cell,
            max_rbmt_per_cell = max_rbmt_per_cell,
            min_intronic_per_cell = min_intronic_per_cell,
            max_intronic_per_cell = max_intronic_per_cell,
            efficiency_threshold_log10 = efficiency_threshold_log10,
            call_stamps_method = call_stamps_method,
            mtx = mtx,
            features = features,
            barcodes = barcodes,
            is_10x = is_10x,
            cbrb_non_empties = cbrb_non_empties,
            cbrb_num_transcripts = cbrb_num_transcripts,
            chimeric_read_metrics_file = chimeric_read_metrics_file,
            barcode_metrics_files = barcode_metrics_files
    }

    call standard_analysis.standard_analysis as standard_analysis {
        input:
            library_name = library_name,
            cell_selection_criteria_label = cell_selection.criteria_label,
            input_bams = input_bams,
            input_digital_expression = input_digital_expression,
            raw_digital_expression = raw_digital_expression,
            raw_digital_expression_summary = raw_digital_expression_summary,
            chimeric_transcripts = chimeric_transcripts,
            reads_per_cell_file = reads_per_cell_file,
            selected_cell_barcodes = cell_selection.cell_file,
            do_discover_meta_genes = do_discover_meta_genes,
            is_cbrb = is_cbrb,
            vcf = vcf,
            vcf_idx = vcf_idx,
            sample_file = sample_file,
            cell_barcode_tag = cell_barcode_tag,
            molecular_barcode_tag = molecular_barcode_tag,
            ignored_chromosomes = ignored_chromosomes,
            locus_function_list = locus_function_list,
            strand_strategy = strand_strategy,
            compute_cbrb_adjusted_likelihoods = compute_cbrb_adjusted_likelihoods,
            cbrb_cell_selection_report = cbrb_cell_selection_report,
            ambient_cell_barcodes = cell_selection.ambient_cell_file,
            sex_caller_config_yaml_file = sex_caller_config_yaml_file,
            census_file = census_file,
            max_error_rate = max_error_rate,
            assign_cells_to_samples_options = assign_cells_to_samples_options,
            detect_doublets_options = detect_doublets_options,
            non_dropulation_donor = non_dropulation_donor
    }

    if (defined(cell_classification_models_tar)
        && defined(sc_pred_model_name)
        && defined(standard_analysis.donors_digital_expression)
        && defined(standard_analysis.donors_digital_expression_summary)
        && defined(standard_analysis.donor_assignments)
        && defined(standard_analysis.donor_cell_map)) {
        call cell_classification.cell_classification as cell_classification {
            input:
                digital_expression = select_first([standard_analysis.donors_digital_expression]),
                digital_expression_summary = select_first([standard_analysis.donors_digital_expression_summary]),
                donor_cell_map = select_first([standard_analysis.donor_cell_map]),
                donor_assignments = select_first([standard_analysis.donor_assignments]),
                cell_classification_models_tar = select_first([cell_classification_models_tar]),
                sc_pred_model_name = select_first([sc_pred_model_name]),
                doublet_finder_pns = doublet_finder_pns,
                doublet_finder_pks = doublet_finder_pks,
                doublet_finder_num_pcs = doublet_finder_num_pcs,
                cbrb_analysis_tag = cbrb_analysis_tag,
                cbrb_cell_selection_report = cbrb_cell_selection_report,
                selected_cell_barcode_file = selected_cell_barcode_file,
                donor_state_file = donor_state_file,
                do_create_metacells_by_cell_type = do_create_metacells_by_cell_type
        }
    }

    output {
        String cell_selection_criteria_label = cell_selection.criteria_label
        File cell_selection_cell_file = cell_selection.cell_file
        File cell_selection_cell_features_rds = cell_selection.cell_features_rds
        File cell_selection_ambient_cell_file = cell_selection.ambient_cell_file
        File cell_selection_pdf = cell_selection.pdf
        File cell_selection_summary_file = cell_selection.summary_file
        File cell_selection_dropped_non_empties_file = cell_selection.dropped_non_empties_file
        File cell_selection_standard_analysis_tear_sheet = cell_selection.standard_analysis_tear_sheet
        File selected_digital_expression = standard_analysis.selected_digital_expression
        File selected_digital_expression_summary = standard_analysis.selected_digital_expression_summary
        File umi_read_intervals = standard_analysis.umi_read_intervals
        File chimeric_transcripts_collapsed = standard_analysis.chimeric_transcripts_collapsed
        File transcript_downsampling = standard_analysis.transcript_downsampling
        File transcript_downsampling_deciles = standard_analysis.transcript_downsampling_deciles
        File transcript_downsampling_pdf = standard_analysis.transcript_downsampling_pdf
        File transcript_downsampling_summary = standard_analysis.transcript_downsampling_summary
        File? ambient_digital_expression = standard_analysis.ambient_digital_expression
        File? ambient_digital_expression_summary = standard_analysis.ambient_digital_expression_summary
        File? ambient_metacells = standard_analysis.ambient_metacells
        File? digital_allele_frequencies = standard_analysis.digital_allele_frequencies
        File? donor_assignments = standard_analysis.donor_assignments
        File? doublet_assignments = standard_analysis.doublet_assignments
        File? summary_stats = standard_analysis.summary_stats
        File? donor_cell_map = standard_analysis.donor_cell_map
        File? donor_cell_barcodes = standard_analysis.donor_cell_barcodes
        File? likely_donors = standard_analysis.likely_donors
        File? dropulation_report_pdf = standard_analysis.dropulation_report_pdf
        File? dropulation_tear_sheet_pdf = standard_analysis.dropulation_tear_sheet_pdf
        File? donors_digital_expression = standard_analysis.donors_digital_expression
        File? donors_digital_expression_summary = standard_analysis.donors_digital_expression_summary
        File? meta_cell_expression = standard_analysis.meta_cell_expression
        File? meta_cell_metrics = standard_analysis.meta_cell_metrics
        File? sex_calls = standard_analysis.sex_calls
        File? sex_calls_pdf = standard_analysis.sex_calls_pdf
        File? metagene_report = standard_analysis.metagene_report
        File? metagene_digital_expression = standard_analysis.metagene_digital_expression
        File? metagene_digital_expression_summary = standard_analysis.metagene_digital_expression_summary
        File? gmg_digital_expression = standard_analysis.gmg_digital_expression
        File? gmg_digital_expression_summary = standard_analysis.gmg_digital_expression_summary
        File? gmg_donors_digital_expression = standard_analysis.gmg_donors_digital_expression
        File? gmg_donors_digital_expression_summary = standard_analysis.gmg_donors_digital_expression_summary
        File? cell_classification_analysis_dir_tgz = cell_classification.analysis_dir_tgz
        File? cell_classification_pred_probs_pdf = cell_classification.pred_probs_pdf
        File? cell_classification_cell_doublet_info = cell_classification.cell_doublet_info
        File? cell_classification_summary_report = cell_classification.summary_report
        File? cell_classification_joined_cell_summary = cell_classification.joined_cell_summary
        File? cell_classification_qc_report = cell_classification.qc_report
        # Phase 1 and 2 pn outputs have the same basenames, causing errors when copying outputs
        # Array[File]? cell_classification_pn_pdf_phase_1 = cell_classification.pn_pdf_phase_1
        # Array[File]? cell_classification_pn_sweep_summary_stats_phase_1 = cell_classification.pn_sweep_summary_stats_phase_1
        # Array[File]? cell_classification_pn_best_pann_dt_phase_1 = cell_classification.pn_best_pann_dt_phase_1
        Array[File]? cell_classification_pn_pdf_phase_2 = cell_classification.pn_pdf_phase_2
        Array[File]? cell_classification_pn_sweep_summary_stats_phase_2 = cell_classification.pn_sweep_summary_stats_phase_2
        Array[File]? cell_classification_pn_best_pann_dt_phase_2 = cell_classification.pn_best_pann_dt_phase_2
        File? cell_classification_parameter_heatmap_phase_1 = cell_classification.parameter_heatmap_phase_1
        File? cell_classification_best_pann_parameters_phase_1 = cell_classification.best_pann_parameters_phase_1
        File? cell_classification_best_pann_pdf_phase_1 = cell_classification.best_pann_pdf_phase_1
        File? cell_classification_doublet_barcodes_phase_1 = cell_classification.doublet_barcodes_phase_1
        File? cell_classification_parameter_heatmap_phase_2 = cell_classification.parameter_heatmap_phase_2
        File? cell_classification_best_pann_parameters_phase_2 = cell_classification.best_pann_parameters_phase_2
        File? cell_classification_best_pann_pdf_phase_2 = cell_classification.best_pann_pdf_phase_2
        File? cell_classification_doublet_barcodes_phase_2 = cell_classification.doublet_barcodes_phase_2
        File? cell_classification_model_pred_probs_iter0 = cell_classification.model_pred_probs_iter0
        File? cell_classification_model_umap_iter0 = cell_classification.model_umap_iter0
        File? cell_classification_model_pred_probs = cell_classification.model_pred_probs
        File? cell_classification_model_umap = cell_classification.model_umap
        File? cell_classification_model_cell_type_counts = cell_classification.model_cell_type_counts
        # Submodel outputs have the same basenames as each other, and the model, causing errors when copying outputs
        # Array[File]? cell_classification_submodel_pred_probs_iter0 = cell_classification.submodel_pred_probs_iter0
        # Array[File]? cell_classification_submodel_umap_iter0 = cell_classification.submodel_umap_iter0
        # Array[File]? cell_classification_submodel_pred_probs = cell_classification.submodel_pred_probs
        # Array[File]? cell_classification_submodel_umap = cell_classification.submodel_umap
        # Array[File]? cell_classification_submodel_cell_type_counts = cell_classification.submodel_cell_type_counts
        Array[File]? cell_classification_metacells_by_cell_type = cell_classification.metacells_by_cell_type
        Array[File]? cell_classification_cell_barcodes_by_cell_type = cell_classification.cell_barcodes_by_cell_type
        Array[File]? cell_classification_cell_barcodes_singlets_by_cell_type = cell_classification.cell_barcodes_singlets_by_cell_type
    }
}
