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

task run_intronic_svm {
    input {
        # required inputs
        File input_file
        String dataset_name
        File cell_features_file

        # optional inputs
        File? features_file
        File? barcodes_file
        Float? cell_probability_threshold
        Int? max_umis_empty
        Array[String]? cell_features_list
        Boolean use_cbrb_features = true
        Boolean force_two_cluster_solution = false

        # optional outputs
        String? out_pdf_path
        String? out_cell_bender_initial_parameters_path
        String? out_features_file_path

        # runtime values
        String docker = "us.gcr.io/mccarroll-scrna-seq/drop-seq_private_r:current"
        Int cpu = 2
        Int memory_mb = 65536
        Int disk_gb = 10
        Int preemptible = 2
    }

    Boolean use_sparse_dge_dir = defined(features_file) && defined(barcodes_file)
    Array[String] cell_features_args = flatten(select_all([cell_features_list]))

    command <<<
        set -euo pipefail

        ~{if use_sparse_dge_dir then "mkdir -p sparse_dge_dir" else ""}
        ~{if use_sparse_dge_dir then "ln -s " + input_file + " sparse_dge_dir/" else ""}
        ~{if use_sparse_dge_dir then "ln -s " + select_first([features_file]) + " sparse_dge_dir/" else ""}
        ~{if use_sparse_dge_dir then "ln -s " + select_first([barcodes_file]) + " sparse_dge_dir/" else ""}

        cell_features_arg='c("~{sep="\",\"" cell_features_args}")'

        Rscript \
            -e 'message(date(), " Start ", "runIntronicSVM")' \
            -e 'suppressPackageStartupMessages(library(Dropseq.cellselection))' \
            -e 'runIntronicSVM(
                datasetName="~{dataset_name}",
                cellFeaturesFile="~{cell_features_file}",
                dgeMatrixFile="~{if use_sparse_dge_dir then "sparse_dge_dir" else input_file}",
                ~{if defined(cell_probability_threshold) then "cellProbabilityThreshold=" + cell_probability_threshold + "," else ""}
                ~{if defined(max_umis_empty) then "maxUmisEmpty=" + max_umis_empty + "," else ""}
                ~{if defined(cell_features_list) then "features=$cell_features_arg," else ""}
                ~{if defined(out_pdf_path) then "outPDF=\"" + out_pdf_path + "\"," else ""}
                ~{if defined(out_cell_bender_initial_parameters_path) then "outCellBenderInitialParameters=\"" + out_cell_bender_initial_parameters_path + "\"," else ""}
                ~{if defined(out_features_file_path) then "outFeaturesFile=\"" + out_features_file_path + "\"," else ""}
                useCBRBFeatures=~{true="TRUE" false="FALSE" use_cbrb_features},
                forceTwoClusterSolution=~{true="TRUE" false="FALSE" force_two_cluster_solution}
            )' \
            -e 'message(date(), " Done ", "runIntronicSVM")'

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
        File? out_pdf = out_pdf_path
        File? out_cell_bender_initial_parameters = out_cell_bender_initial_parameters_path
        File? out_features_file = out_features_file_path
    }
}
