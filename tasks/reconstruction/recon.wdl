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

task recon {
    input {
        # Required inputs
        String bcl
        String recon_name
        File recon_count_tar

        # Optional inputs
        Int? bead
        Float? diameter
        Boolean knn_filter = false
        Int? n_neighbors
        Int? local_connectivity
        Float? spread
        Float? min_dist
        Float? repulsion_strength
        Int? negative_sample_rate
        Int? n_epochs
        File? recon_py
        File? helpers_py

        # Runtime values
        String docker = "quay.io/broadinstitute/macosko-pipelines_reconstruction:current"
        Int cpu = 16
        Int memory_gb = 16
        Int disk_gb = 10 + ceil(size(recon_count_tar, "GB"))
        # This job takes a long time to run, and seems to preempt often enough to exhaust the premption count anyway
        Int preemptible = 0
    }

    String parent_recon_count_dir = "recon-count"
    String parent_recon_dir = "recon"
    String in_dir = parent_recon_count_dir + "/" + bcl + "/" + recon_name
    String out_dir = parent_recon_dir + "/" + bcl + "/" + recon_name

    command <<<
        set -euo pipefail

        mkdir -p ~{parent_recon_count_dir}
        tar -C ~{parent_recon_count_dir} -xvf ~{recon_count_tar}

        ln -s ~{if defined(recon_py) then recon_py else "/usr/local/bin/reconstruction/recon.py"} recon.py
        ln -s ~{if defined(helpers_py) then helpers_py else "/usr/local/bin/reconstruction/helpers.py"} helpers.py

        mkdir -p out_pdf

        MAMBA_ROOT_PREFIX=/root/micromamba /root/.local/bin/micromamba run \
            python \
            recon.py \
            --in_dir ~{in_dir} \
            --out_dir ~{out_dir} \
            --cores ~{cpu} \
            ~{if defined(bead) then "--bead " + bead else ""} \
            ~{if defined(diameter) then "--diameter " + diameter else ""} \
            ~{if knn_filter then "--knn_filter" else "" } \
            ~{if defined(n_neighbors) then "--n_neighbors " + n_neighbors else ""} \
            ~{if defined(local_connectivity) then "--local_connectivity " + local_connectivity else ""} \
            ~{if defined(spread) then "--spread " + spread else ""} \
            ~{if defined(min_dist) then "--min_dist " + min_dist else ""} \
            ~{if defined(repulsion_strength) then "--repulsion_strength " + repulsion_strength else ""} \
            ~{if defined(negative_sample_rate) then "--negative_sample_rate " + negative_sample_rate else ""} \
            ~{if defined(n_epochs) then "--n_epochs " + n_epochs else ""}

        umap_name=$(basename $(ls -d ~{out_dir}/UMAP*))
        printf "%s\n" $umap_name > umap_name.txt

        tar -C ~{parent_recon_dir} -cvf ~{recon_name}.$umap_name.recon.tar ~{bcl}
        cp ~{out_dir}/$umap_name/summary.pdf out_pdf/~{recon_name}.$umap_name.summary.pdf
    >>>

    runtime {
        docker: docker
        cpu: cpu
        memory: memory_gb + " GB"
        disks: "local-disk " + disk_gb + " HDD"
        preemptible: preemptible
    }

    output {
        String umap_name = read_string("umap_name.txt")
        File recon_tar = recon_name + "." + umap_name + ".recon.tar"
        File summary_pdf = "out_pdf/" + recon_name + "." + umap_name + ".summary.pdf"
    }
}
