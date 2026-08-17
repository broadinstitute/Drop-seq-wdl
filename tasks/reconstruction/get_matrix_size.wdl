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

task get_matrix_size {
    input {
        # Required inputs
        File recon_count_tar

        # Runtime values
        String docker = "ubuntu"
        Int cpu = 2
        Int memory_gb = 2
        Int disk_gb = 10
        Int preemptible = 0
    }

    String parent_recon_count_dir = "recon-count"

    command <<<
        set -euo pipefail

        mkdir -p ~{parent_recon_count_dir}
        tar -C ~{parent_recon_count_dir} -xvf ~{recon_count_tar}
        matrix_csv_gz=$(find ~{parent_recon_count_dir} -name matrix.csv.gz)
        recon_count_dir=$(dirname $matrix_csv_gz)
        recon_name=$(basename $recon_count_dir)
        bcl_name=$(basename $(dirname $recon_count_dir))
        printf "%s\n" $recon_name > recon_name.txt
        printf "%s\n" $bcl_name > bcl_name.txt
    >>>

    runtime {
        docker: docker
        cpu: cpu
        memory: memory_gb + " GB"
        disks: "local-disk " + disk_gb + " HDD"
        preemptible: preemptible
    }

    output {
        String bcl_name = read_string("bcl_name.txt")
        String recon_name = read_string("recon_name.txt")
        File matrix_csv_gz = parent_recon_count_dir + "/" + bcl_name + "/" + recon_name + "/matrix.csv.gz"
        Float matrix_gb = size(matrix_csv_gz, "GB")
    }
}
