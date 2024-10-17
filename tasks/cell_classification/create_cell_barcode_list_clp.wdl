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

task create_cell_barcode_list_clp {
    input {
        # required inputs
        String analysis_dir
        Array[File] prior_analysis_dir_tars
        String pred_probs_path
        String doublet_finder_path

        # required outputs
        Array[String] output_cell_type_file_paths
        Array[String] output_cell_type_singlet_file_paths
        String output_dir_path

        # runtime values
        String docker = "us.gcr.io/mccarroll-scrna-seq/drop-seq_private_r:current"
        Int cpu = 2
        Int memory_mb = 4096
        Int disk_gb = 10
        Int preemptible = 2
    }

    command <<<
        set -euo pipefail

        mkdir -p ~{analysis_dir}

        for prior_analysis_dir_tar in ~{sep=" " prior_analysis_dir_tars}; do
            tar -xvf ${prior_analysis_dir_tar}
        done

        pushd ~{analysis_dir}
        mkdir -p ~{output_dir_path}
        Rscript \
            -e 'message(date(), " Start ", "createCellBarcodeListsClp")' \
            -e 'suppressPackageStartupMessages(library(DropSeq.cellclassification))' \
            -e 'createCellBarcodeListsClp(
                pred.probs.path="~{pred_probs_path}",
                doublet.finder.path="~{doublet_finder_path}",
                output.dir="~{output_dir_path}"
            )' \
            -e 'message(date(), " Done ", "createCellBarcodeListsClp")'
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
        Array[File] output_cell_type_files = output_cell_type_file_paths
        Array[File] output_cell_type_singlet_files = output_cell_type_singlet_file_paths
        File analysis_dir_tar = analysis_dir + ".tar"
    }
}
