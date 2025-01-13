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

task call_stamps {
    input {
        # required inputs
        String dataset_name
        File cell_features_file

        # optional inputs
        Int? min_umis_per_cell
        Int? max_umis_per_cell
        Int? max_rbmt_per_cell
        Float? min_intronic_per_cell
        Float? max_intronic_per_cell
        Float? efficiency_threshold_log10
        String? call_stamps_method
        File? mtx
        File? features
        File? barcodes
        Boolean is_10x = true
        File? cbrb_non_empties
        File? cbrb_retained_umis

        # required outputs
        String out_cell_file_path
        String out_cell_features_rds_path
        String out_ambient_cell_file_path
        String out_pdf_path
        String out_summary_file_path

        # optional outputs
        String? out_dropped_non_empties_file_path

        # runtime values
        String docker = "us.gcr.io/mccarroll-scrna-seq/drop-seq_private_r:current"
        Int cpu = 2
        Int memory_mb = if (select_first([call_stamps_method, ""]) == "svm_nuclei") then 65536 else 4096
        Int disk_gb = 10
        Int preemptible = 2
    }

    Boolean is_svm_nuclei = select_first([call_stamps_method, ""]) == "svm_nuclei"

    command <<<
        set -euo pipefail

        ~{if is_svm_nuclei then "mkdir -p sparse_dge_dir" else ""}
        ~{if is_svm_nuclei then "ln -s " + mtx + " sparse_dge_dir/" else ""}
        ~{if is_svm_nuclei then "ln -s " + features + " sparse_dge_dir/" else ""}
        ~{if is_svm_nuclei then "ln -s " + barcodes + " sparse_dge_dir/" else ""}

        Rscript \
            -e 'message(date(), " Start ", "CallSTAMPs")' \
            -e 'suppressPackageStartupMessages(library(Dropseq.cellselection))' \
            -e 'CallSTAMPs(
                dataset_name="~{dataset_name}",
                outCellFeaturesRds="~{out_cell_features_rds_path}",
                outCellFile="~{out_cell_file_path}",
                outPDF="~{out_pdf_path}",
                outSummaryFile="~{out_summary_file_path}",
                is_10x=~{if is_10x then "TRUE" else "FALSE"},
                ~{if defined(min_umis_per_cell) then "minUMIsPerCell=" + min_umis_per_cell + "," else ""}
                ~{if defined(max_umis_per_cell) then "maxUMIsPerCell=" + max_umis_per_cell + "," else ""}
                ~{if defined(max_rbmt_per_cell) then "maxRBMTPerCell=" + max_rbmt_per_cell + "," else ""}
                ~{if defined(min_intronic_per_cell) then "minIntronicPerCell=" + min_intronic_per_cell + "," else ""}
                ~{if defined(max_intronic_per_cell) then "maxIntronicPerCell=" + max_intronic_per_cell + "," else ""}
                ~{if defined(efficiency_threshold_log10) then "efficiencyThresholdLog10=" + efficiency_threshold_log10 + "," else ""}
                ~{if defined(call_stamps_method) then "method_selected=\"" + call_stamps_method + "\"," else ""}
                cbrbNonEmptiesFile=~{if defined(cbrb_non_empties) then "\"" + cbrb_non_empties + "\"" else "NULL"},
                cbrbRetainedUMIsFile=~{if defined(cbrb_retained_umis) then "\"" + cbrb_retained_umis + "\"" else "NULL"},
                outAmbientCellFile="~{out_ambient_cell_file_path}",
                outDroppedNonEmptiesFile="~{out_dropped_non_empties_file_path}",
                ~{if is_svm_nuclei then "sparseDgeDir=\"sparse_dge_dir\"," else ""}
                cellFeaturesFile="~{cell_features_file}",
            )' \
            -e 'message(date(), " Done ", "CallSTAMPs")'

        grep -avE '^/(Creation|Mod)Date' ~{out_pdf_path} > ~{out_pdf_path}.tmp
        mv ~{out_pdf_path}.tmp ~{out_pdf_path}
    >>>

    runtime {
        docker: docker
        cpu: cpu
        memory: memory_mb + " MB"
        disks: "local-disk " + disk_gb + " HDD"
        preemptible: preemptible
    }

    output {
        File out_cell_file = out_cell_file_path
        File out_cell_features_rds = out_cell_features_rds_path
        File out_ambient_cell_file = out_ambient_cell_file_path
        File out_pdf = out_pdf_path
        File out_summary_file = out_summary_file_path
        File? out_dropped_non_empties_file = out_dropped_non_empties_file_path
    }
}
