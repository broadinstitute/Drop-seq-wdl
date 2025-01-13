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

task call_sex_from_metacells {
    input {
        # required inputs
        String analysis_identifier
        File sex_caller_config_yaml_file
        File input_metacell_file
        File input_metacell_metrics_file

        # required outputs
        String output_sex_call_file_path
        String output_hist_pdf_file_path

        # runtime values
        String docker = "us.gcr.io/mccarroll-scrna-seq/drop-seq_private_r:current"
        Int cpu = 2
        Int memory_mb = 4096
        Int disk_gb = 10
        Int preemptible = 2
    }

    command <<<
        set -euo pipefail

        Rscript \
            -e 'message(date(), " Start ", "callSexFromMetacells")' \
            -e 'suppressPackageStartupMessages(library(DropSeq.xipher))' \
            -e 'callSexFromMetacells(
                outputSexCallFile="~{output_sex_call_file_path}",
                analysisIdentifier="~{analysis_identifier}",
                sexCallerConfigYamlFile="~{sex_caller_config_yaml_file}",
                inputMetacellFile="~{input_metacell_file}",
                ouputHistPdfFile="~{output_hist_pdf_file_path}",
                inputMetacellMetricsFile="~{input_metacell_metrics_file}"
            )' \
            -e 'message(date(), " Done ", "callSexFromMetacells")'

        grep -avE '^/(Creation|Mod)Date' ~{output_sex_call_file_path} > ~{output_sex_call_file_path}.tmp
        mv ~{output_sex_call_file_path}.tmp ~{output_sex_call_file_path}
    >>>

    runtime {
        docker: docker
        cpu: cpu
        memory: memory_mb + " MB"
        disks: "local-disk " + disk_gb + " HDD"
        preemptible: preemptible
    }

    output {
        File output_sex_call_file = output_sex_call_file_path
        File output_hist_pdf_file = output_hist_pdf_file_path
    }
}
