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

import "../../pipelines/cell_selection/cell_selection.wdl"
import "../../pipelines/dropseq_cbrb/dropseq_cbrb.wdl"
import "../../pipelines/optimus_post_processing/optimus_post_processing.wdl"

workflow optimus_auto_cell_selection {
    input {
        # required inputs
        String library_name # v123_10X-GEX-3P_abc_rxn8
        String experiment_date # 2024-01-01
        File optimus_bam
        File optimus_h5ad
        File gtf

        # optional inputs
        Int? min_umis_per_cell # 500
        Int? max_umis_per_cell
        Int? max_rbmt_per_cell
        Float? min_intronic_per_cell # 0.55
        Float? max_intronic_per_cell
        Float? efficiency_threshold_log10
        String? call_stamps_method # svm_nuclei
        Int num_transcripts_threshold = 20
        Int split_bam_size_gb = 2
        String? cell_barcode_tag # CB
        String? chimeric_molecular_barcode_tag # UR
        Array[String] locus_function_list = [] # ["INTRONIC"]
        Int? expected_cells
        Int? total_droplets_included
        Boolean use_svm_parameter_estimation = true
        Int num_training_tries = 3
        Float final_elbo_fail_fraction = 0.1
        Float? learning_rate
        String cbrb_other_args = ""
        String cbrb_docker_image = "us.gcr.io/broad-dsde-methods/cellbender:0.3.2"
        String cbrb_hardware_zones = "us-central1-a us-central1-c"
        Boolean is_10x = true
        Array[File] barcode_metrics_files = []
    }

    call optimus_post_processing.optimus_post_processing as optimus_post_processing {
        input:
            library_name = library_name,
            optimus_bam = optimus_bam,
            optimus_h5ad = optimus_h5ad,
            gtf = gtf,
            num_transcripts_threshold = num_transcripts_threshold,
            split_bam_size_gb = split_bam_size_gb,
            cell_barcode_tag = cell_barcode_tag,
            chimeric_molecular_barcode_tag = chimeric_molecular_barcode_tag,
            locus_function_list = locus_function_list
    }

    call dropseq_cbrb.dropseq_cbrb as dropseq_cbrb {
        input:
            library_name = library_name,
            experiment_date = experiment_date,
            raw_digital_expression = optimus_post_processing.digital_expression,
            read_quality_metrics = optimus_post_processing.read_quality_metrics,
            cell_selection_report = optimus_post_processing.cell_selection_report,
            mtx = optimus_post_processing.mtx,
            features = optimus_post_processing.features,
            barcodes = optimus_post_processing.barcodes,
            expected_cells = expected_cells,
            total_droplets_included = total_droplets_included,
            use_svm_parameter_estimation = use_svm_parameter_estimation,
            num_training_tries = num_training_tries,
            final_elbo_fail_fraction = final_elbo_fail_fraction,
            learning_rate = learning_rate,
            cbrb_other_args = cbrb_other_args,
            cbrb_docker_image = cbrb_docker_image,
            cbrb_hardware_zones = cbrb_hardware_zones
    }

    call cell_selection.cell_selection as cell_selection {
        input:
            library_name = library_name,
            cell_selection_report = optimus_post_processing.cell_selection_report,
            read_quality_metrics = optimus_post_processing.read_quality_metrics,
            min_umis_per_cell = min_umis_per_cell,
            max_umis_per_cell = max_umis_per_cell,
            max_rbmt_per_cell = max_rbmt_per_cell,
            min_intronic_per_cell = min_intronic_per_cell,
            max_intronic_per_cell = max_intronic_per_cell,
            efficiency_threshold_log10 = efficiency_threshold_log10,
            call_stamps_method = call_stamps_method,
            mtx = optimus_post_processing.mtx,
            features = optimus_post_processing.features,
            barcodes = optimus_post_processing.barcodes,
            is_10x = is_10x,
            cbrb_non_empties = dropseq_cbrb.cbrb_selected_cell_barcodes,
            cbrb_num_transcripts = dropseq_cbrb.cbrb_num_transcripts,
            chimeric_read_metrics_file = optimus_post_processing.chimeric_read_metrics,
            barcode_metrics_files = barcode_metrics_files
    }

    output {
        File dropseq_h5ad = optimus_post_processing.dropseq_h5ad
        File digital_expression = optimus_post_processing.digital_expression
        File digital_expression_summary = optimus_post_processing.digital_expression_summary
        File mtx = optimus_post_processing.mtx
        File features = optimus_post_processing.features
        File barcodes = optimus_post_processing.barcodes
        File reads_per_cell = optimus_post_processing.reads_per_cell
        File read_quality_metrics = optimus_post_processing.read_quality_metrics
        File cell_selection_report = optimus_post_processing.cell_selection_report
        Array[File] dropseq_bam = optimus_post_processing.dropseq_bam
        File dropseq_bam_manifest = optimus_post_processing.dropseq_bam_manifest
        File chimeric_transcripts = optimus_post_processing.chimeric_transcripts
        File chimeric_read_metrics = optimus_post_processing.chimeric_read_metrics
        String cbrb_analysis_tag = dropseq_cbrb.cbrb_analysis_tag
        File cbrb_summary_pdf = dropseq_cbrb.cbrb_summary_pdf
        File cbrb_cell_barcodes_csv = dropseq_cbrb.cbrb_cell_barcodes_csv
        File cbrb_metrics_csv = dropseq_cbrb.cbrb_metrics_csv
        File cbrb_html_report = dropseq_cbrb.cbrb_html_report
        File cbrb_h5 = dropseq_cbrb.cbrb_h5
        File cbrb_checkpoint_file = dropseq_cbrb.cbrb_checkpoint_file
        File cbrb_plateau_pdf = dropseq_cbrb.cbrb_plateau_pdf
        File cbrb_digital_expression = dropseq_cbrb.cbrb_digital_expression
        File cbrb_num_transcripts = dropseq_cbrb.cbrb_num_transcripts
        File cbrb_contam_fraction_params = dropseq_cbrb.cbrb_contam_fraction_params
        File cbrb_elbo_table = dropseq_cbrb.cbrb_elbo_table
        File cbrb_tearsheet_pdf = dropseq_cbrb.cbrb_tearsheet_pdf
        File cbrb_pdf = dropseq_cbrb.cbrb_pdf
        File cbrb_selected_cell_barcodes = dropseq_cbrb.cbrb_selected_cell_barcodes
        File cbrb_cell_selection_report = dropseq_cbrb.cbrb_cell_selection_report
        File cbrb_tearsheet_txt = dropseq_cbrb.cbrb_tearsheet_txt
        String cell_selection_criteria_label = cell_selection.criteria_label
        File cell_selection_cell_file = cell_selection.cell_file
        File cell_selection_cell_features_rds = cell_selection.cell_features_rds
        File cell_selection_ambient_cell_file = cell_selection.ambient_cell_file
        File cell_selection_pdf = cell_selection.pdf
        File cell_selection_summary_file = cell_selection.summary_file
        File cell_selection_dropped_non_empties_file = cell_selection.dropped_non_empties_file
        File cell_selection_standard_analysis_tear_sheet = cell_selection.standard_analysis_tear_sheet
        File? cbrb_svm_cbrb_parameter_estimation_pdf = dropseq_cbrb.cbrb_svm_cbrb_parameter_estimation_pdf
        File? cbrb_svm_cbrb_parameter_estimation_txt = dropseq_cbrb.cbrb_svm_cbrb_parameter_estimation_txt
    }
}