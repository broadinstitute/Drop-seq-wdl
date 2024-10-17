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

task parse_cell_classification_models {
    input {
        # required inputs
        File cell_classification_models_tar
        String model_txt_path
        String sc_pred_model_name

        # runtime values
        String docker = "linuxserver/yq:3.4.3"
        Int cpu = 2
        Int memory_mb = 4096
        Int disk_gb = 10
        Int preemptible = 2
    }

    command <<<
        set -euo pipefail

        touch sc_pred_submodel_names.txt
        touch sc_pred_submodel_paths.txt
        touch sc_pred_submodel_celltypes.txt

        tar -xvf ~{cell_classification_models_tar}

        yq -r '.[] | select(.name == "~{sc_pred_model_name}") | .path' ~{model_txt_path} > sc_pred_model_path.txt
        for submodel in $(yq -r '.[] | select(.name == "~{sc_pred_model_name}") | .submodels // [] | .[]' ~{model_txt_path}); do
            echo $submodel >> sc_pred_submodel_names.txt
            yq -r '.[] | select(.name == "'${submodel}'") | .path' ~{model_txt_path} >> sc_pred_submodel_paths.txt
            yq -r '.[] | select(.name == "'${submodel}'") | .celltype' ~{model_txt_path} >> sc_pred_submodel_celltypes.txt
        done
    >>>

    runtime {
        docker: docker
        cpu: cpu
        memory: memory_mb + " MB"
        disks: "local-disk " + disk_gb + " HDD"
        preemptible: preemptible
    }

    output {
        String sc_pred_model_path = read_string("sc_pred_model_path.txt")
        Array[String] sc_pred_submodel_names = read_lines("sc_pred_submodel_names.txt")
        Array[String] sc_pred_submodel_paths = read_lines("sc_pred_submodel_paths.txt")
        Array[String] sc_pred_submodel_celltypes = read_lines("sc_pred_submodel_celltypes.txt")
    }
}
