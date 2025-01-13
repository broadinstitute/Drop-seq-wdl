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

task make_cell_classification_plots_clp {
    input {
        # required inputs
        String analysis_dir
        Array[File] prior_analysis_dir_tars
        String data_dir_path

        # optional inputs
        String? doublet_finder_path
        File? donor_assignment_path
        Boolean do_donor_assignment_plots = defined(donor_assignment_path)
        File? dge_summary_path
        File? donor_state_path

        # required outputs
        String output_pdf_path

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

        pdf_path=$(realpath ~{output_pdf_path})

        pushd ~{analysis_dir}
        Rscript \
            -e 'message(date(), " Start ", "makeCellClassificationPlotsClp")' \
            -e 'suppressPackageStartupMessages(library(DropSeq.cellclassification))' \
            -e 'makeCellClassificationPlotsClp(
                pdf.path="'${pdf_path}'",
                donor.assignment.path=~{if do_donor_assignment_plots then "\"" + donor_assignment_path + "\"" else "NULL"},
                donor.state.path=~{if defined(donor_state_path) then "\"" + donor_state_path + "\"" else "NULL"},
                dge.summary.path=~{if defined(dge_summary_path) then "\"" + dge_summary_path + "\"" else "NULL"},
                doublet.finder.path=~{if defined(doublet_finder_path) then "\"" + doublet_finder_path + "\"" else "NULL"},
                data.dir="~{data_dir_path}"
            )' \
            -e 'message(date(), " Done ", "makeCellClassificationPlotsClp")'
        popd
        grep -avE '^/(Creation|Mod)Date' ~{output_pdf_path} > ~{output_pdf_path}.tmp
        mv ~{output_pdf_path}.tmp ~{output_pdf_path}

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
        File output_pdf = output_pdf_path
        File analysis_dir_tar = analysis_dir + ".tar"
    }
}
