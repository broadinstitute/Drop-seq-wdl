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

task classify_cells_clp {
    input {
        # required inputs
        String analysis_dir
        Array[File] prior_analysis_dir_tars = []
        File cell_classification_models_tar
        String cell_classification_models_dir
        String scpred_model_path
        File raw_dge_path

        # optional inputs
        File? cell_barcode_file
        String? cell_barcode_path

        # required outputs
        String output_pred_probs_iter0_path
        String output_umap_iter0_path
        String output_pred_probs_path
        String output_umap_path
        String output_cell_type_counts_path
        String output_dir_path

        # runtime values
        String docker = "us.gcr.io/mccarroll-scrna-seq/drop-seq_private_r:current"
        Int cpu = 2
        Int memory_mb = 16384
        Int disk_gb = 10
        Int preemptible = 2
    }

    command <<<
        set -euo pipefail

        mkdir -p ~{analysis_dir}

        for prior_analysis_dir_tar in ~{sep=" " prior_analysis_dir_tars}; do
            tar -xvf ${prior_analysis_dir_tar}
        done

        mkdir -p ~{cell_classification_models_dir}

        tar -xvf ~{cell_classification_models_tar}

        scpred_model_path=$(realpath ~{cell_classification_models_dir}/~{scpred_model_path})

        pushd ~{analysis_dir}
        mkdir -p ~{output_dir_path}
        Rscript \
            -e 'message(date(), " Start ", "classifyCellsClp")' \
            -e 'suppressPackageStartupMessages(library(DropSeq.cellclassification))' \
            -e 'classifyCellsClp(
                raw.dge.path="~{raw_dge_path}",
                scpred.model.path="'${scpred_model_path}'",
                cell.barcode.path=~{if defined(cell_barcode_file) then "\"" + cell_barcode_file + "\"" else if defined(cell_barcode_path) then "\"" + cell_barcode_path + "\"" else "NULL"},
                output.dir="~{output_dir_path}"
            )' \
            -e 'message(date(), " Done ", "classifyCellsClp")'
        popd

        tar -cvf ~{analysis_dir}.tar ~{analysis_dir}
    >>>

    runtime {
        docker: docker
        cpu: cpu
        memory: memory_mb + " MB"
        disks: "local-disk " + disk_gb + " HDD"
        preemptible: preemptible
    }

    output {
        File output_pred_probs_iter0 = output_pred_probs_iter0_path
        File output_umap_iter0 = output_umap_iter0_path
        File output_pred_probs = output_pred_probs_path
        File output_umap = output_umap_path
        File output_cell_type_counts = output_cell_type_counts_path
        File analysis_dir_tar = analysis_dir + ".tar"
    }
}
