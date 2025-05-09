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

task make_cbrb_0_3_0_tear_sheet_properties {
    input {
        # required inputs
        File rb_num_transcripts_file
        File read_quality_metrics_file
        File cbrb_metrics_csv
        File yaml_properties_file
        File cbrb_non_empty_cells_file
        File cell_features_file
        String launch_date
        String cbrb_args

        # required outputs
        String out_file_path

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
            -e 'message(date(), " Start ", "makeCbrb_0.3.0_TearSheetProperties")' \
            -e 'suppressPackageStartupMessages(library(Dropseq.cellselection))' \
            -e 'makeCbrb_0.3.0_TearSheetProperties(
                outFile="~{out_file_path}",
                launchDate="~{launch_date}",
                rbNumTranscriptsFile="~{rb_num_transcripts_file}",
                readQualityMetricsFile="~{read_quality_metrics_file}",
                cbrbMetricsCsv="~{cbrb_metrics_csv}",
                yamlPropertiesFile="~{yaml_properties_file}",
                cbrbNonEmptyCellsFile="~{cbrb_non_empty_cells_file}",
                cbrbArgs="~{cbrb_args}",
                cellFeaturesFile="~{cell_features_file}"
            )' \
            -e 'message(date(), " Done ", "makeCbrb_0.3.0_TearSheetProperties")'
    >>>

    runtime {
        docker: docker
        cpu: cpu
        memory: memory_mb + " MB"
        disks: "local-disk " + disk_gb + " HDD"
        preemptible: preemptible
    }

    output {
        File out_file = out_file_path
    }
}
