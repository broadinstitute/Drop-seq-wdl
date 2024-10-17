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

task create_summary_report_clp {
    input {
        # required inputs
        String analysis_dir
        Array[File] prior_analysis_dir_tars
        Array[String] model_names
        String pred_probs_path_template
        String doublet_finder_path

        # required outputs
        String output_summary_report_path

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

        model_names=''
        pred_probs_paths=''
        for model_name in ~{sep=" " model_names}; do
            model_names="${model_names},${model_name}"
            pred_probs_paths="${pred_probs_paths},~{pred_probs_path_template}"
        done
        model_names=${model_names:1}
        pred_probs_paths=${pred_probs_paths:1}

        summary_report_path=$(realpath ~{output_summary_report_path})

        pushd ~{analysis_dir}
        Rscript \
            -e 'message(date(), " Start ", "createSummaryReportClp")' \
            -e 'suppressPackageStartupMessages(library(DropSeq.cellclassification))' \
            -e 'createSummaryReportClp(
                model.names="'${model_names}'",
                pred.probs.paths="'${pred_probs_paths}'",
                doublet.finder.path="~{doublet_finder_path}",
                summary.report.path="'${summary_report_path}'"
            )' \
            -e 'message(date(), " Done ", "createSummaryReportClp")'
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
        File output_summary_report = output_summary_report_path
        File analysis_dir_tar = analysis_dir + ".tar"
    }
}
