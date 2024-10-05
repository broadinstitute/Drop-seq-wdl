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

task join_cell_metadata {
    input {
        # required inputs
        String analysis_dir
        Array[File] prior_analysis_dir_tars = []
        File digital_expression
        File digital_expression_summary
        File scpred_cell_type_summary_report
        File donor_cell_map
        File donor_assignments

        # optional inputs
        String? cbrb_analysis_tag
        File? rb_cell_selection_report

        # required outputs
        String output_summary_path

        # runtime values
        String docker = "us.gcr.io/mccarroll-scrna-seq/drop-seq_private_python:current"
        Int cpu = 2
        Int memory_mb = 4096
        Int disk_gb = 10
        Int preemptible = 2
    }

    Boolean has_cbrb = defined(cbrb_analysis_tag) && defined(rb_cell_selection_report)

    command <<<
        set -euo pipefail

        ~{if defined(cbrb_analysis_tag) then "mkdir -p cbrb/" + cbrb_analysis_tag else ""}
        mkdir -p std_analysis/cell_selection/~{analysis_dir}

        dge_name=$(basename ~{digital_expression})
        dge_properties=${dge_name}
        dge_properties=${dge_properties%.gz}
        dge_properties=${dge_properties%.txt}
        dge_properties=${dge_properties%.digital_expression}
        dge_properties=${dge_properties%.donors}
        dge_properties=${dge_properties}.properties
        ~{if has_cbrb then "echo \"CBRB_DIRECTORY=$(realpath cbrb/" + cbrb_analysis_tag + ")\" > std_analysis/cell_selection/$dge_properties" else ""}

        ln -s ~{digital_expression} std_analysis/cell_selection/$dge_name
        ln -s ~{digital_expression_summary} std_analysis/cell_selection/~{basename(digital_expression_summary)}
        ln -s ~{scpred_cell_type_summary_report} std_analysis/cell_selection/~{analysis_dir}/~{basename(scpred_cell_type_summary_report)}
        ln -s ~{donor_cell_map} std_analysis/cell_selection/~{basename(donor_cell_map)}
        ln -s ~{donor_assignments} std_analysis/cell_selection/~{basename(donor_assignments)}
        ~{if has_cbrb then "ln -s " + select_first([rb_cell_selection_report]) + " cbrb/" + cbrb_analysis_tag + "/" + basename(select_first([rb_cell_selection_report])) else ""}

        pushd std_analysis/cell_selection
        for prior_analysis_dir_tar in ~{sep=" " prior_analysis_dir_tars}; do
            tar -xvf ${prior_analysis_dir_tar}
        done
        popd

        join_cell_metadata \
            --out std_analysis/cell_selection/~{output_summary_path} \
            dge std_analysis/cell_selection/$dge_name

        pushd std_analysis/cell_selection
        tar -cvf ~{analysis_dir}.tar ~{analysis_dir}
        popd
    >>>

    runtime {
        docker: docker
        cpu: cpu
        memory: memory_mb + " MB"
        disks: "local-disk " + disk_gb + " HDD"
        preemptible: preemptible
    }

    output {
        File output_summary = "std_analysis/cell_selection/" + output_summary_path
        File analysis_dir_tar = "std_analysis/cell_selection/" + analysis_dir + ".tar"
    }
}
