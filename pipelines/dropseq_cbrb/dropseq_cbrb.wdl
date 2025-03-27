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

import "https://raw.githubusercontent.com/broadinstitute/CellBender/v0.3.2/wdl/cellbender_remove_background.wdl"
import "../../tasks/common/merge_dge.wdl"
import "../../tasks/dropseq_cbrb/cbrb_0_3_0_tear_sheet.wdl"
import "../../tasks/dropseq_cbrb/dump_elbo_table.wdl"
import "../../tasks/dropseq_cbrb/dump_hdf5_element.wdl"
import "../../tasks/dropseq_cbrb/fix_cbrb_non_empty_list_clp.wdl"
import "../../tasks/dropseq_cbrb/hdf5_10x_to_text.wdl"
import "../../tasks/dropseq_cbrb/join_cbrb_cell_features.wdl"
import "../../tasks/dropseq_cbrb/make_cbrb_0_3_0_tear_sheet_properties.wdl"
import "../../tasks/dropseq_cbrb/make_cbrb_args.wdl"
import "../../tasks/dropseq_cbrb/make_launch_date.wdl"
import "../../tasks/dropseq_cbrb/parse_svm_parameter_estimation_file.wdl"
import "../../tasks/dropseq_cbrb/plateau_plot_pdf_clp.wdl"
import "../../tasks/dropseq_cbrb/plot_cbrb_0_3_0_result.wdl"
import "../../tasks/dropseq_cbrb/run_intronic_svm.wdl"

workflow dropseq_cbrb {
    input {
        # required inputs
        String library_name # v123_10X-GEX-3P_abc_rxn8
        String experiment_date # 2024-01-01
        File raw_digital_expression # <alignment_dir>/<library_name>.digital_expression.txt.gz
        File read_quality_metrics # <alignment_dir>/<library_name>.ReadQualityMetrics.txt
        File cell_selection_report # <alignment_dir>/<library_name>.cell_selection_report.txt

        # optional inputs
        File? mtx
        File? features
        File? barcodes
        Int? expected_cells
        Int? total_droplets_included
        Boolean use_svm_parameter_estimation = !(defined(expected_cells) && defined(total_droplets_included))
        Boolean force_two_cluster_solution = false
        Int num_training_tries = 3
        Float final_elbo_fail_fraction = 0.1
        Float learning_rate = 0.0000125
        String cbrb_other_args = ""
        String cbrb_docker_image = "us.gcr.io/broad-dsde-methods/cellbender:0.3.2"
        String cbrb_hardware_zones = "us-central1-a us-central1-c"
    }

    call make_launch_date.make_launch_date as make_launch_date

    call make_cbrb_args.make_cbrb_args as make_cbrb_args {
        input:
            workflow_command_line = "cellbender_remove_background.wdl " + library_name,
            raw_digital_expression_path = basename(raw_digital_expression),
            library_name = library_name,
            expected_cells = expected_cells,
            total_droplets_included = total_droplets_included,
            num_training_tries = num_training_tries,
            final_elbo_fail_fraction = final_elbo_fail_fraction,
            learning_rate = learning_rate,
            cbrb_gls_yaml_path = "cbrb.gls.yaml",
            cbrb_properties_yaml_path = library_name + ".cbrb.properties.yaml"
    }

    String analysis_identifier = library_name + "." + make_cbrb_args.analysis_tag

    if (use_svm_parameter_estimation) {
        call run_intronic_svm.run_intronic_svm as run_intronic_svm {
            input:
                input_file = select_first([mtx]),
                dataset_name = analysis_identifier,
                cell_features_file = cell_selection_report,
                features_file = features,
                barcodes_file = barcodes,
                use_cbrb_features = false,
                force_two_cluster_solution = force_two_cluster_solution,
                out_pdf_path = analysis_identifier + ".svm_cbrb_parameter_estimation.pdf",
                out_cell_bender_initial_parameters_path = analysis_identifier + ".svm_cbrb_parameter_estimation.txt"
        }

        call parse_svm_parameter_estimation_file.parse_svm_parameter_estimation_file as parse_svm_parameter_estimation_file {
            input:
                svm_parameter_estimation_file = select_first([run_intronic_svm.out_cell_bender_initial_parameters])
        }
    }

    call plateau_plot_pdf_clp.plateau_plot_pdf_clp as plateau_plot_pdf_clp {
        input:
            cell_features_file = cell_selection_report,
            title = analysis_identifier,
            total_droplets_included = total_droplets_included,
            expected_cells = expected_cells,
            svm_cbrb_parameter_estimation_file = run_intronic_svm.out_cell_bender_initial_parameters,
            out_pdf_path = analysis_identifier + ".plateau.pdf"
    }

    if (!(defined(mtx) && defined(features) && defined(barcodes))) {
        call merge_dge.merge_dge as merge_dge {
            input:
                input_expression = [raw_digital_expression],
                output_header = false,
                output_format = "MM_SPARSE_10X",
                output_file_path = "matrix.mtx.gz",
                output_features_path = "features.tsv.gz",
                output_cells_path = "barcodes.tsv.gz"
        }
    }

    Array[Int] expected_cells_array = select_all([expected_cells, parse_svm_parameter_estimation_file.expected_cells])
    if (length(expected_cells_array) > 0) {
        Int expected_cells_option = expected_cells_array[0]
    }

    Array[Int] total_droplets_included_array = select_all([total_droplets_included, parse_svm_parameter_estimation_file.total_droplets_included])
    if (length(total_droplets_included_array) > 0) {
        Int total_droplets_included_option = total_droplets_included_array[0]
    }

    call cellbender_remove_background.run_cellbender_remove_background_gpu as cbrb {
        input:
            sample_name = library_name,
            model = "full " + cbrb_other_args, # inject the other args into the string argument "model"
            input_file_unfiltered = select_first([merge_dge.output_file, mtx]),
            barcodes_file = select_first([merge_dge.output_cells, barcodes]),
            genes_file = select_first([merge_dge.output_features, features]),
            expected_cells = expected_cells_option,
            total_droplets_included = total_droplets_included_option,
            final_elbo_fail_fraction = final_elbo_fail_fraction,
            num_training_tries = num_training_tries,
            learning_rate = learning_rate,
            docker_image = cbrb_docker_image,
            hardware_zones = cbrb_hardware_zones
    }

    # Igonre missing HTML reports: https://github.com/broadinstitute/CellBender/issues/337
    if (length(cbrb.report_array) > 0) {
        File cbrb_html_report_option = cbrb.report_array[0]
    }

    call hdf5_10x_to_text.hdf5_10x_to_text as hdf5_10x_to_text {
        input:
            input_h5 = cbrb.h5_array[0],
            header = raw_digital_expression,
            command_yaml = make_cbrb_args.cbrb_gls_yaml,
            output_file_path = library_name + ".cbrb.digital_expression.txt.gz",
            output_sizes_path = library_name + ".cbrb.num_transcripts.txt",
    }

    call dump_hdf5_element.dump_hdf5_element as dump_hdf5_element {
        input:
            input_h5 = cbrb.h5_array[0],
            element_name = "swapping_fraction_dist_params",
            group_path = "/global_latents",
            output_file_path = library_name + ".contam_fraction_params.txt"
    }

    call dump_elbo_table.dump_elbo_table as dump_elbo_table {
        input:
            input_h5 = cbrb.h5_array[0],
            output_file_path = library_name + ".elbo.txt"
    }

    call plot_cbrb_0_3_0_result.plot_cbrb_0_3_0_result as plot_cbrb_0_3_0_result {
        input:
            contamination_fraction_params_file = dump_hdf5_element.output_file,
            rb_num_transcripts_file = hdf5_10x_to_text.output_sizes,
            rb_selected_cells_file = cbrb.cell_csv,
            cell_features_file = cell_selection_report,
            cbrb_metrics_csv = cbrb.metrics_array[0],
            lib_name = library_name,
            append_pdfs = [cbrb.pdf],
            out_pdf_path = library_name + ".cbrb.pdf"
    }

    call fix_cbrb_non_empty_list_clp.fix_cbrb_non_empty_list_clp as fix_cbrb_non_empty_list_clp {
        input:
            non_empties_file = cbrb.cell_csv,
            num_transcripts_file = hdf5_10x_to_text.output_sizes,
            out_non_empties_file_path = library_name + ".cbrb.selectedCellBarcodes.txt"
    }

    call join_cbrb_cell_features.join_cbrb_cell_features as join_cbrb_cell_features {
        input:
            cell_features_file = cell_selection_report,
            cbrb_retained_umis_file = hdf5_10x_to_text.output_sizes,
            out_file_path = library_name + ".cbrb.cell_selection_report.txt"
    }

    call cbrb_0_3_0_tear_sheet.cbrb_0_3_0_tear_sheet as cbrb_0_3_0_tear_sheet {
        input:
            elbo_file = dump_elbo_table.output_file,
            cbrb_metrics_csv = cbrb.metrics_array[0],
            rb_selected_cells_file = cbrb.cell_csv,
            cell_features_file = cell_selection_report,
            cbrb_retained_umis_file = hdf5_10x_to_text.output_sizes,
            read_quality_metrics_file = read_quality_metrics,
            title = experiment_date + "_" + analysis_identifier,
            append_pdfs = [cbrb.pdf],
            out_file_path = library_name + ".cbrb.tearsheet.pdf"
    }

    call make_cbrb_0_3_0_tear_sheet_properties.make_cbrb_0_3_0_tear_sheet_properties as make_cbrb_0_3_0_tear_sheet_properties {
        input:
            rb_num_transcripts_file = hdf5_10x_to_text.output_sizes,
            read_quality_metrics_file = read_quality_metrics,
            cbrb_metrics_csv = cbrb.metrics_array[0],
            yaml_properties_file = make_cbrb_args.cbrb_properties_yaml,
            cbrb_non_empty_cells_file = fix_cbrb_non_empty_list_clp.out_non_empties_file,
            cell_features_file = cell_selection_report,
            launch_date = make_launch_date.launch_date,
            cbrb_args = make_cbrb_args.cbrb_args,
            out_file_path = library_name + ".cbrb.tearsheet.txt"
    }

    output {
        String cbrb_analysis_tag = make_cbrb_args.analysis_tag
        File cbrb_summary_pdf = cbrb.pdf
        File cbrb_cell_barcodes_csv = cbrb.cell_csv
        File cbrb_metrics_csv = cbrb.metrics_array[0]
        File? cbrb_html_report = cbrb_html_report_option
        File cbrb_h5 = cbrb.h5_array[0]
        File cbrb_checkpoint_file = cbrb.ckpt_file
        File cbrb_plateau_pdf = plateau_plot_pdf_clp.out_pdf
        File cbrb_digital_expression = hdf5_10x_to_text.output_file
        File cbrb_num_transcripts = hdf5_10x_to_text.output_sizes
        File cbrb_contam_fraction_params = dump_hdf5_element.output_file
        File cbrb_elbo_table = dump_elbo_table.output_file
        File cbrb_tearsheet_pdf = cbrb_0_3_0_tear_sheet.out_file
        File cbrb_pdf = plot_cbrb_0_3_0_result.out_pdf
        File cbrb_selected_cell_barcodes = fix_cbrb_non_empty_list_clp.out_non_empties_file
        File cbrb_cell_selection_report = join_cbrb_cell_features.out_file
        File cbrb_tearsheet_txt = make_cbrb_0_3_0_tear_sheet_properties.out_file
        File? cbrb_svm_cbrb_parameter_estimation_pdf = run_intronic_svm.out_pdf
        File? cbrb_svm_cbrb_parameter_estimation_txt = run_intronic_svm.out_cell_bender_initial_parameters
    }
}
