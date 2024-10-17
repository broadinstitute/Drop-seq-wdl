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

import "../../tasks/cell_selection/call_stamps.wdl"
import "../../tasks/cell_selection/make_cell_selection_args.wdl"
import "../../tasks/cell_selection/make_standard_analysis_tear_sheet.wdl"

workflow cell_selection {
    input {
        # required inputs
        String library_name # v123_10X-GEX-3P_abc_rxn8
        File cell_selection_report # <alignment_dir>/<library_name>.cell_selection_report.txt
        File read_quality_metrics # <alignment_dir>/<library_name>.ReadQualityMetrics.txt

        # optional inputs
        Int? min_umis_per_cell # 500
        Int? max_umis_per_cell
        Int? max_rbmt_per_cell
        Float? min_intronic_per_cell # 0.55
        Float? max_intronic_per_cell
        Float? efficiency_threshold_log10
        String? call_stamps_method # svm_nuclei
        File? mtx
        File? features
        File? barcodes
        Boolean is_10x = true
        File? cbrb_non_empties # <cbrb_dir>/<library_name>.cbrb.selectedCellBarcodes.txt
        File? cbrb_num_transcripts # <cbrb_dir>/<library_name>.cbrb.num_transcripts.txt
        File? chimeric_read_metrics_file # <alignment_dir>/<library_name>.chimeric_read_metrics
        Array[File] barcode_metrics_files = []
    }

    call make_cell_selection_args.make_cell_selection_args as make_cell_selection_args {
        input:
            min_umis_per_cell = min_umis_per_cell,
            max_umis_per_cell = max_umis_per_cell,
            max_rbmt_per_cell = max_rbmt_per_cell,
            min_intronic_per_cell = min_intronic_per_cell,
            max_intronic_per_cell = max_intronic_per_cell,
            efficiency_threshold_log10 = efficiency_threshold_log10,
            call_stamps_method = call_stamps_method,
            is_10x = is_10x
    }

    String standard_analysis_id = library_name + "." + make_cell_selection_args.criteria_label
    String cbrb_disambiguator = if defined(cbrb_non_empties) then ".cbrb" else ""

    if (defined(cbrb_non_empties)) {
        String optional_out_dropped_non_empties_file_path = standard_analysis_id + ".not_cell_not_empty.txt"
    }

    if (select_first([call_stamps_method, ""]) == "svm_nuclei") {
        File optional_mtx = select_first([mtx])
        File optional_features = select_first([features])
        File optional_barcodes = select_first([barcodes])
    }

    call call_stamps.call_stamps as call_stamps {
        input:
            dataset_name = standard_analysis_id + cbrb_disambiguator,
            cell_features_file = cell_selection_report,
            min_umis_per_cell = min_umis_per_cell,
            max_umis_per_cell = max_umis_per_cell,
            max_rbmt_per_cell = max_rbmt_per_cell,
            min_intronic_per_cell = min_intronic_per_cell,
            max_intronic_per_cell = max_intronic_per_cell,
            efficiency_threshold_log10 = efficiency_threshold_log10,
            call_stamps_method = call_stamps_method,
            mtx = optional_mtx,
            features = optional_features,
            barcodes = optional_barcodes,
            is_10x = is_10x,
            cbrb_non_empties = cbrb_non_empties,
            cbrb_retained_umis = cbrb_num_transcripts,
            out_cell_file_path = standard_analysis_id + ".selectedCellBarcodes.txt",
            out_cell_features_rds_path = standard_analysis_id + ".cell_features.RDS",
            out_ambient_cell_file_path = standard_analysis_id + ".ambient.cellBarcodes.txt",
            out_pdf_path = standard_analysis_id + ".cell_selection_assignments.pdf",
            out_summary_file_path = standard_analysis_id + ".cell_selection_assignments_summary.txt",
            out_dropped_non_empties_file_path = optional_out_dropped_non_empties_file_path
    }

    call make_standard_analysis_tear_sheet.make_standard_analysis_tear_sheet as make_standard_analysis_tear_sheet {
        input:
            alignment_quality_file = read_quality_metrics,
            chimeric_read_metrics_file = chimeric_read_metrics_file,
            cell_selection_summary_file = call_stamps.out_summary_file,
            barcode_metrics_files = barcode_metrics_files,
            out_file_path = standard_analysis_id + ".tear_sheet.txt"
    }

    output {
        String criteria_label = make_cell_selection_args.criteria_label
        File cell_file = call_stamps.out_cell_file
        File cell_features_rds = call_stamps.out_cell_features_rds
        File ambient_cell_file = call_stamps.out_ambient_cell_file
        File pdf = call_stamps.out_pdf
        File summary_file = call_stamps.out_summary_file
        File dropped_non_empties_file = select_first([call_stamps.out_dropped_non_empties_file])
        File standard_analysis_tear_sheet = make_standard_analysis_tear_sheet.out_file
    }
}
