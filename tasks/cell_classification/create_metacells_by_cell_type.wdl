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

task create_metacells_by_cell_type {
    input {
        # required inputs
        String analysis_dir
        Array[File] prior_analysis_dir_tars
        File raw_dge_path
        File donor_assignment_path
        String pred_probs_path

        # required outputs
        Array[String] output_cell_type_file_paths
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

        pred_probs_path=$(realpath ~{pred_probs_path})

        pushd ~{analysis_dir}
        mkdir -p ~{output_dir_path}
        Rscript \
            -e 'message(date(), " Start ", "createMetacellsByCellType")' \
            -e 'suppressPackageStartupMessages(library(DropSeq.cellclassification))' \
            -e 'createMetacellsByCellType(
                raw.dge.path="~{raw_dge_path}",
                donor.assignment.path="~{donor_assignment_path}",
                pred.probs.path="'${pred_probs_path}'",
                output.dir="~{output_dir_path}"
            )' \
            -e 'message(date(), " Done ", "createMetacellsByCellType")'
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
        File analysis_dir_tar = analysis_dir + ".tar"
    }
}
