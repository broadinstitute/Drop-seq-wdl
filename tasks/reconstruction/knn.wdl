# MIT License
#
# Copyright 2026 Broad Institute
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

task knn {
    input {
        # Required inputs
        String bcl
        String recon_name
        String tar_suffix
        Array[File] recon_count_files

        # Optional inputs
        Int? n_neighbors
        Int? bead
        Int? chunks
        File? knn_py

        # Runtime values
        String docker = "quay.io/broadinstitute/macosko-pipelines_reconstruction:current"
        Int cpu = 16
        Int memory_gb = 16
        Int disk_gb = 10 + 5 * ceil(size(recon_count_files, "GB"))
        # This job takes a long time to run, and seems to preempt often enough to exhaust the premption count anyway
        Int preemptible = 0
    }

    String parent_recon_count_dir = "recon-count"
    String out_dir = parent_recon_count_dir + "/" + bcl + "/" + recon_name

    command <<<
        set -euo pipefail

        mkdir -p ~{out_dir}

        for recon_count_file in ~{sep=" " recon_count_files}; do
            ln -s $recon_count_file ~{out_dir}/
        done

        MAMBA_ROOT_PREFIX=/root/micromamba /root/.local/bin/micromamba run \
            python \
            ~{if defined(knn_py) then knn_py else "/usr/local/bin/reconstruction/knn.py"} \
            --in_dir ~{out_dir} \
            --out_dir ~{out_dir} \
            --cores ~{cpu} \
            ~{if defined(n_neighbors) then "--n_neighbors " + n_neighbors else ""} \
            ~{if defined(bead) then "--bead " + bead else ""} \
            ~{if defined(chunks) then "--chunks " + chunks else ""}

        tar -C ~{parent_recon_count_dir} -cvhf ~{recon_name}.recon-count.~{tar_suffix}.tar ~{bcl}
    >>>

    runtime {
        docker: docker
        cpu: cpu
        memory: memory_gb + " GB"
        disks: "local-disk " + disk_gb + " HDD"
        preemptible: preemptible
    }

    output {
        File recon_count_tar = recon_name + ".recon-count." + tar_suffix + ".tar"
    }
}
