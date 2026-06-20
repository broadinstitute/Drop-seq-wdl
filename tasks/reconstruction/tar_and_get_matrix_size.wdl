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

task tar_and_get_matrix_size {
    input {
        # Required inputs
        String local_recon_dir
        String bcl_name
        String recon_name

        # Runtime values
        String docker = "ubuntu"
        Int cpu = 2
        Int memory_gb = 2
        Int disk_gb = 10
        Int preemptible = 0
    }

    String parent_recon_count_dir = "recon-count"
    String recon_count_dir = local_recon_dir + "/" + bcl_name + "/" + recon_name

    command <<<
        set -euo pipefail

        mkdir -p ~{parent_recon_count_dir}/~{bcl_name}/~{recon_name}
        find ~{recon_count_dir} \
            -maxdepth 1 \
            -type f \
            -exec ln -s {} ~{parent_recon_count_dir}/~{bcl_name}/~{recon_name}/ \;
        tar -C ~{parent_recon_count_dir} -cvhf ~{recon_name}.recon-count.tar ~{bcl_name}
    >>>

    runtime {
        docker: docker
        cpu: cpu
        memory: memory_gb + " GB"
        disks: "local-disk " + disk_gb + " HDD"
        preemptible: preemptible
    }

    output {
        File recon_count_tar = recon_name + ".recon-count.tar"
        File matrix_csv_gz = recon_count_dir + "/matrix.csv.gz"
        Float matrix_gb = size(matrix_csv_gz, "GB")
    }
}
