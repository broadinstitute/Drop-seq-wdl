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

task run_doublet_finder_parameter_sweep_clp {
    input {
        # required inputs
        String analysis_dir
        String phase
        File raw_dge_path
        Float pn

        # optional inputs
        Array[File] prior_analysis_dir_tars = []
        String? prior_doublet_barcode_rds
        File? cell_barcode_path
        Array[Int] n_pcs_seq = []
        Array[Float] pk_seq = []

        # required outputs
        String output_pn_pdf_path
        String output_pn_sweep_summary_stats_path
        String output_pn_best_pann_dt_path
        String output_dir_path

        # runtime values
        String docker = "us.gcr.io/mccarroll-scrna-seq/drop-seq_private_r:current"
        Int cpu = 2
        Int memory_mb = 65536
        Int disk_gb = 10
        Int preemptible = 2
    }

    command <<<
        set -euo pipefail

        mkdir -p ~{analysis_dir}

        for prior_analysis_dir_tar in ~{sep=" " prior_analysis_dir_tars}; do
            tar -xvf ${prior_analysis_dir_tar}
        done

        n_pcs_seq_arg='c("~{sep="\",\"" n_pcs_seq}")'
        pk_seq_arg='c("~{sep="\",\"" pk_seq}")'

        pushd ~{analysis_dir}
        mkdir -p ~{output_dir_path}/~{phase}
        Rscript \
            -e 'message(date(), " Start ", "runDoubletFinderParameterSweepClp")' \
            -e 'suppressPackageStartupMessages(library(DropSeq.cellclassification))' \
            -e 'runDoubletFinderParameterSweepClp(
                cell.barcode.path=~{if defined(cell_barcode_path) then "\"" + cell_barcode_path + "\"" else "NULL"},
                output.dir="~{output_dir_path}/~{phase}",
                pn=~{pn},
                n.pcs.seq=~{if length(n_pcs_seq) > 0 then "'$n_pcs_seq_arg'" else "c()"},
                pk.seq=~{if length(pk_seq) > 0 then "'$pk_seq_arg'" else "c()"},
                prior.doublet.barcode.rds=~{if defined(prior_doublet_barcode_rds) then "\"" + prior_doublet_barcode_rds + "\"" else "NULL"},
                raw.dge.path="~{raw_dge_path}"
            )' \
            -e 'message(date(), " Done ", "runDoubletFinderParameterSweepClp")'
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
        File output_pn_pdf = output_pn_pdf_path
        File output_pn_sweep_summary_stats = output_pn_sweep_summary_stats_path
        File output_pn_best_pann_dt = output_pn_best_pann_dt_path
        File analysis_dir_tar = analysis_dir + ".tar"
    }
}
