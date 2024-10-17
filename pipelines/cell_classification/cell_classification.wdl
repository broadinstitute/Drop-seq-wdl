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

import "../../tasks/cell_classification/classify_cells_clp.wdl"
import "../../tasks/cell_classification/create_cell_barcode_list_clp.wdl"
import "../../tasks/cell_classification/create_metacells_by_cell_type.wdl"
import "../../tasks/cell_classification/create_quality_metrics_report_clp.wdl"
import "../../tasks/cell_classification/create_summary_report_clp.wdl"
import "../../tasks/cell_classification/join_cell_metadata.wdl"
import "../../tasks/cell_classification/make_cell_classification_plots_clp.wdl"
import "../../tasks/cell_classification/merge_analysis_dir_tars.wdl"
import "../../tasks/cell_classification/parse_cell_classification_models.wdl"
import "../../tasks/cell_classification/parse_cell_types.wdl"
import "../../tasks/cell_classification/run_doublet_finder_parameter_sweep_clp.wdl"
import "../../tasks/cell_classification/select_best_parameters_clp.wdl"

workflow cell_classification {
    input {
        # required inputs
        File digital_expression #: <standard_analysis_dir>/<standard_analysis_id>.donors.digital_expression.txt.gz
        File digital_expression_summary #: <standard_analysis_dir>/<standard_analysis_id>.donors.digital_expression_summary.txt
        File donor_cell_map #: <standard_analysis_dir>/<standard_analysis_id>.donor_cell_map.txt
        File donor_assignments #: <standard_analysis_dir>/<standard_analysis_id>.donor_assignments.txt
        File cell_classification_models_tar # <cell_classification_models_dir>.tar
        String sc_pred_model_name #: "caudate"

        # optional inputs
        Array[Float] doublet_finder_pns = [0.4, 0.45, 0.5]
        Array[Float] doublet_finder_pks = []
        Array[Int] doublet_finder_num_pcs = []
        String? cbrb_analysis_tag # auto
        File? cbrb_cell_selection_report #: <cbrb_dir>/<library_name>.cbrb.cell_selection_report.txt
        File? selected_cell_barcode_file # optional
        File? donor_state_file # optional
        Boolean do_create_metacells_by_cell_type = false
    }

    String analysis_dir = "scPred"
    String cell_classification_models_dir = "cell_classification_models"

    call parse_cell_classification_models.parse_cell_classification_models as parse_cell_classification_models {
        input:
            cell_classification_models_tar = cell_classification_models_tar,
            model_txt_path = cell_classification_models_dir + "/models.txt",
            sc_pred_model_name = sc_pred_model_name
    }

    scatter (idx in range(length(doublet_finder_pns))) {
        call run_doublet_finder_parameter_sweep_clp.run_doublet_finder_parameter_sweep_clp as run_doublet_finder_parameter_sweep_clp_phase_1 {
            input:
                analysis_dir = analysis_dir,
                phase = "phase_1",
                raw_dge_path = digital_expression,
                pn = doublet_finder_pns[idx],
                n_pcs_seq = doublet_finder_num_pcs,
                pk_seq = doublet_finder_pks,
                output_pn_pdf_path = analysis_dir + "/doublet_finder/phase_1/pn_" + doublet_finder_pns[idx] + "_component_singlet_distances_and_homotypic_threshold.pdf",
                output_pn_sweep_summary_stats_path = analysis_dir + "/doublet_finder/phase_1/pn_" + doublet_finder_pns[idx] + "_sweep_summary_stats.RDS",
                output_pn_best_pann_dt_path = analysis_dir + "/doublet_finder/phase_1/pn_" + doublet_finder_pns[idx] + "_best_pann_dt.RDS",
                output_dir_path = "doublet_finder"
        }
    }

    call select_best_parameters_clp.select_best_parameters_clp as select_best_parameters_clp_phase_1 {
        input:
            analysis_dir = analysis_dir,
            phase = "phase_1",
            prior_analysis_dir_tars = run_doublet_finder_parameter_sweep_clp_phase_1.analysis_dir_tar,
            num_clusters = 3,
            output_parameter_heatmap_path = analysis_dir + "/doublet_finder/phase_1_parameter_heatmap.png",
            output_best_pann_parameters_path = analysis_dir + "/doublet_finder/phase_1_best_pann_parameters.txt",
            output_best_pann_pdf_path = analysis_dir + "/doublet_finder/phase_1_best_pann.pdf",
            output_doublet_barcodes_path = analysis_dir + "/doublet_finder/phase_1_doublet_barcodes.RDS",
            output_dir_path = "doublet_finder"
    }

    scatter (idx in range(length(doublet_finder_pns))) {
        call run_doublet_finder_parameter_sweep_clp.run_doublet_finder_parameter_sweep_clp as run_doublet_finder_parameter_sweep_clp_phase_2 {
            input:
                analysis_dir = analysis_dir,
                phase = "phase_2",
                raw_dge_path = digital_expression,
                pn = doublet_finder_pns[idx],
                n_pcs_seq = doublet_finder_num_pcs,
                pk_seq = doublet_finder_pks,
                prior_analysis_dir_tars = [select_best_parameters_clp_phase_1.analysis_dir_tar],
                prior_doublet_barcode_rds = "doublet_finder/phase_1_doublet_barcodes.RDS",
                output_pn_pdf_path = analysis_dir + "/doublet_finder/phase_2/pn_" + doublet_finder_pns[idx] + "_component_singlet_distances_and_homotypic_threshold.pdf",
                output_pn_sweep_summary_stats_path = analysis_dir + "/doublet_finder/phase_2/pn_" + doublet_finder_pns[idx] + "_sweep_summary_stats.RDS",
                output_pn_best_pann_dt_path = analysis_dir + "/doublet_finder/phase_2/pn_" + doublet_finder_pns[idx] + "_best_pann_dt.RDS",
                output_dir_path = "doublet_finder"
        }
    }

    call select_best_parameters_clp.select_best_parameters_clp as select_best_parameters_clp_phase_2 {
        input:
            analysis_dir = analysis_dir,
            phase = "phase_2",
            prior_analysis_dir_tars = run_doublet_finder_parameter_sweep_clp_phase_2.analysis_dir_tar,
            num_clusters = 2,
            output_parameter_heatmap_path = analysis_dir + "/doublet_finder/phase_2_parameter_heatmap.png",
            output_best_pann_parameters_path = analysis_dir + "/doublet_finder/phase_2_best_pann_parameters.txt",
            output_best_pann_pdf_path = analysis_dir + "/doublet_finder/phase_2_best_pann.pdf",
            output_doublet_barcodes_path = analysis_dir + "/doublet_finder/phase_2_doublet_barcodes.RDS",
            output_dir_path = "doublet_finder",
            output_cell_doublet_info_path = analysis_dir + "/doublet_finder/cell_doublet_info.txt"
    }

    call classify_cells_clp.classify_cells_clp as classify_cells_clp_model {
        input:
            analysis_dir = analysis_dir,
            cell_classification_models_tar = cell_classification_models_tar,
            cell_classification_models_dir = cell_classification_models_dir,
            scpred_model_path = parse_cell_classification_models.sc_pred_model_path,
            raw_dge_path = digital_expression,
            cell_barcode_file = selected_cell_barcode_file,
            output_pred_probs_iter0_path = analysis_dir + "/model_" + sc_pred_model_name + "/pred_probs.iter0.txt",
            output_umap_iter0_path = analysis_dir + "/model_" + sc_pred_model_name + "/umap.iter0.txt",
            output_pred_probs_path = analysis_dir + "/model_" + sc_pred_model_name + "/pred_probs.txt",
            output_umap_path = analysis_dir + "/model_" + sc_pred_model_name + "/umap.txt",
            output_cell_type_counts_path = analysis_dir + "/model_" + sc_pred_model_name + "/cell_type.counts.txt",
            output_dir_path = "model_" + sc_pred_model_name
    }

    call parse_cell_types.parse_cell_types as parse_cell_types {
        input:
            pred_probs = classify_cells_clp_model.output_pred_probs
    }

    scatter (idx in range(length(parse_cell_types.cell_types))) {
        String cell_type = parse_cell_types.cell_types[idx]
        String cell_type_metacells = analysis_dir + "/model_" + sc_pred_model_name + "/metacels/" + cell_type + ".txt.gz" # sic
        String cell_type_barcodes = analysis_dir + "/model_" + sc_pred_model_name + "/cell_barcodes/" + cell_type + ".txt"
        String cell_type_singlets = analysis_dir + "/model_" + sc_pred_model_name + "/cell_barcodes/" + cell_type + ".singlet.txt"
    }

    if (do_create_metacells_by_cell_type) {
        call create_metacells_by_cell_type.create_metacells_by_cell_type as create_metacells_by_cell_type {
            input:
                analysis_dir = analysis_dir,
                prior_analysis_dir_tars = [classify_cells_clp_model.analysis_dir_tar],
                raw_dge_path = digital_expression,
                donor_assignment_path = donor_assignments,
                pred_probs_path = "model_" + sc_pred_model_name + "/pred_probs.txt",
                output_cell_type_file_paths = cell_type_metacells,
                output_dir_path = "model_" + sc_pred_model_name + "/metacels" # sic
        }
    }

    call make_cell_classification_plots_clp.make_cell_classification_plots_clp as make_cell_classification_plots_clp {
        input:
            analysis_dir = analysis_dir,
            prior_analysis_dir_tars = [classify_cells_clp_model.analysis_dir_tar, select_best_parameters_clp_phase_2.analysis_dir_tar],
            data_dir_path = "model_" + sc_pred_model_name,
            doublet_finder_path = "doublet_finder/cell_doublet_info.txt",
            dge_summary_path = digital_expression_summary,
            donor_assignment_path = donor_assignments,
            do_donor_assignment_plots = do_create_metacells_by_cell_type,
            donor_state_path = donor_state_file,
            output_pdf_path = analysis_dir + "/model_" + sc_pred_model_name + "/pred_probs.pdf"
    }

    call create_cell_barcode_list_clp.create_cell_barcode_list_clp as create_cell_barcode_list_clp {
        input:
            analysis_dir = analysis_dir,
            prior_analysis_dir_tars = [classify_cells_clp_model.analysis_dir_tar, select_best_parameters_clp_phase_2.analysis_dir_tar],
            pred_probs_path = "model_" + sc_pred_model_name + "/pred_probs.txt",
            doublet_finder_path = "doublet_finder/cell_doublet_info.txt",
            output_cell_type_file_paths = cell_type_barcodes,
            output_cell_type_singlet_file_paths = cell_type_singlets,
            output_dir_path = "model_" + sc_pred_model_name + "/cell_barcodes"
    }

    scatter (idx in range(length(parse_cell_classification_models.sc_pred_submodel_names))) {
        String sc_pred_submodel_name = parse_cell_classification_models.sc_pred_submodel_names[idx]
        String sc_pred_submodel_celltype = parse_cell_classification_models.sc_pred_submodel_celltypes[idx]
        call classify_cells_clp.classify_cells_clp as classify_cells_clp_submodel {
            input:
                analysis_dir = analysis_dir,
                prior_analysis_dir_tars = [create_cell_barcode_list_clp.analysis_dir_tar],
                cell_classification_models_tar = cell_classification_models_tar,
                cell_classification_models_dir = cell_classification_models_dir,
                scpred_model_path = parse_cell_classification_models.sc_pred_submodel_paths[idx],
                raw_dge_path = digital_expression,
                cell_barcode_path = "model_" + sc_pred_model_name + "/cell_barcodes/" + sc_pred_submodel_celltype + ".singlet.txt",
                output_pred_probs_iter0_path = analysis_dir + "/model_" + sc_pred_submodel_name + "/pred_probs.iter0.txt",
                output_umap_iter0_path = analysis_dir + "/model_" + sc_pred_submodel_name + "/umap.iter0.txt",
                output_pred_probs_path = analysis_dir + "/model_" + sc_pred_submodel_name + "/pred_probs.txt",
                output_umap_path = analysis_dir + "/model_" + sc_pred_submodel_name + "/umap.txt",
                output_cell_type_counts_path = analysis_dir + "/model_" + sc_pred_submodel_name + "/cell_type.counts.txt",
                output_dir_path = "model_" + parse_cell_classification_models.sc_pred_submodel_names[idx]
        }
    }

    call create_summary_report_clp.create_summary_report_clp as create_summary_report_clp {
        input:
            analysis_dir = analysis_dir,
            prior_analysis_dir_tars = flatten([[classify_cells_clp_model.analysis_dir_tar, select_best_parameters_clp_phase_2.analysis_dir_tar], classify_cells_clp_submodel.analysis_dir_tar]),
            model_names = flatten([[sc_pred_model_name], parse_cell_classification_models.sc_pred_submodel_names]),
            pred_probs_path_template = "model_$model_name/pred_probs.txt",
            doublet_finder_path = "doublet_finder/cell_doublet_info.txt",
            output_summary_report_path = analysis_dir + "/cell_type.summary.report.txt"
    }

    call join_cell_metadata.join_cell_metadata as join_cell_metadata {
        input:
            analysis_dir = analysis_dir,
            prior_analysis_dir_tars = [create_summary_report_clp.analysis_dir_tar],
            digital_expression = digital_expression,
            digital_expression_summary = digital_expression_summary,
            scpred_cell_type_summary_report = create_summary_report_clp.output_summary_report,
            donor_cell_map = donor_cell_map,
            donor_assignments = donor_assignments,
            cbrb_analysis_tag = cbrb_analysis_tag,
            rb_cell_selection_report = cbrb_cell_selection_report,
            output_summary_path = analysis_dir + "/summary.txt"
    }

    call create_quality_metrics_report_clp.create_quality_metrics_report_clp as create_quality_metrics_report_clp {
        input:
            analysis_dir = analysis_dir,
            prior_analysis_dir_tars = [join_cell_metadata.analysis_dir_tar],
            joined_cell_summary_path = "summary.txt",
            output_metrics_report_path = analysis_dir + "/qc.report.txt"
    }

    call merge_analysis_dir_tars.merge_analysis_dir_tars as merge_analysis_dir_tars {
        input:
            analysis_dir = analysis_dir,
            prior_analysis_dir_tars = select_all([make_cell_classification_plots_clp.analysis_dir_tar, create_metacells_by_cell_type.analysis_dir_tar, create_quality_metrics_report_clp.analysis_dir_tar])
    }

    output {
        File analysis_dir_tgz = merge_analysis_dir_tars.analysis_dir_tgz
        File pred_probs_pdf = make_cell_classification_plots_clp.output_pdf
        File cell_doublet_info = select_first([select_best_parameters_clp_phase_2.output_cell_doublet_info])
        File summary_report = create_summary_report_clp.output_summary_report
        File joined_cell_summary = join_cell_metadata.output_summary
        File qc_report = create_quality_metrics_report_clp.output_metrics_report
        # Phase 1 and 2 pn outputs have the same basenames, causing errors when copying outputs
        # Array[File] pn_pdf_phase_1 = run_doublet_finder_parameter_sweep_clp_phase_1.output_pn_pdf
        # Array[File] pn_sweep_summary_stats_phase_1 = run_doublet_finder_parameter_sweep_clp_phase_1.output_pn_sweep_summary_stats
        # Array[File] pn_best_pann_dt_phase_1 = run_doublet_finder_parameter_sweep_clp_phase_1.output_pn_best_pann_dt
        Array[File] pn_pdf_phase_2 = run_doublet_finder_parameter_sweep_clp_phase_2.output_pn_pdf
        Array[File] pn_sweep_summary_stats_phase_2 = run_doublet_finder_parameter_sweep_clp_phase_2.output_pn_sweep_summary_stats
        Array[File] pn_best_pann_dt_phase_2 = run_doublet_finder_parameter_sweep_clp_phase_2.output_pn_best_pann_dt
        File parameter_heatmap_phase_1 = select_best_parameters_clp_phase_1.output_parameter_heatmap
        File best_pann_parameters_phase_1 = select_best_parameters_clp_phase_1.output_best_pann_parameters
        File best_pann_pdf_phase_1 = select_best_parameters_clp_phase_1.output_best_pann_pdf
        File doublet_barcodes_phase_1 = select_best_parameters_clp_phase_1.output_doublet_barcodes
        File parameter_heatmap_phase_2 = select_best_parameters_clp_phase_2.output_parameter_heatmap
        File best_pann_parameters_phase_2 = select_best_parameters_clp_phase_2.output_best_pann_parameters
        File best_pann_pdf_phase_2 = select_best_parameters_clp_phase_2.output_best_pann_pdf
        File doublet_barcodes_phase_2 = select_best_parameters_clp_phase_2.output_doublet_barcodes
        File model_pred_probs_iter0 = classify_cells_clp_model.output_pred_probs_iter0
        File model_umap_iter0 = classify_cells_clp_model.output_umap_iter0
        File model_pred_probs = classify_cells_clp_model.output_pred_probs
        File model_umap = classify_cells_clp_model.output_umap
        File model_cell_type_counts = classify_cells_clp_model.output_cell_type_counts
        # Submodel outputs have the same basenames as each other, and the model, causing errors when copying outputs
        # Array[File] submodel_pred_probs_iter0 = classify_cells_clp_submodel.output_pred_probs_iter0
        # Array[File] submodel_umap_iter0 = classify_cells_clp_submodel.output_umap_iter0
        # Array[File] submodel_pred_probs = classify_cells_clp_submodel.output_pred_probs
        # Array[File] submodel_umap = classify_cells_clp_submodel.output_umap
        # Array[File] submodel_cell_type_counts = classify_cells_clp_submodel.output_cell_type_counts
        Array[File]? metacells_by_cell_type = create_metacells_by_cell_type.output_cell_type_files
        Array[File] cell_barcodes_by_cell_type = create_cell_barcode_list_clp.output_cell_type_files
        Array[File] cell_barcodes_singlets_by_cell_type = create_cell_barcode_list_clp.output_cell_type_singlet_files
    }
}
