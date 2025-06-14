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

task optimus_h5ad_to_dropseq {
    input {
        # required inputs
        File input_h5ad

        # optional inputs
        Int? min_transcripts

        # optional outputs
        String? output_h5ad_path
        String? output_mtx_path
        String? output_barcodes_path
        String? output_features_path
        String? output_digital_expression_path
        String? output_digital_expression_summary_path
        String? output_reads_per_cell_file_path
        String? output_read_quality_metrics_path
        String? output_cell_selection_report_path

        # runtime values
        String docker = "quay.io/broadinstitute/drop-seq_python:current"
        Int cpu = 2
        Int memory_mb = 8192
        # 2x the output_mtx_path because of re_gz
        Int disk_gb = 10 + if defined(output_mtx_path) then 2 * ceil(50 * size(input_h5ad, "GB")) else 0
        Int preemptible = 2
    }

    # Uses re_gz to strip the timestamp from outputs so they will be deterministic and call-cacheable.
    command <<<
        set -euo pipefail

        dropseq_hdf5 optimus_h5ad_to_dropseq \
            --input ~{input_h5ad} \
            ~{if defined(min_transcripts) then "--min_transcripts " + min_transcripts else ""} \
            ~{if defined(output_h5ad_path) then "--h5ad " + output_h5ad_path else ""} \
            ~{if defined(output_mtx_path) then "--mtx " + output_mtx_path else ""} \
            ~{if defined(output_barcodes_path) then "--barcodes " + output_barcodes_path else ""} \
            ~{if defined(output_features_path) then "--features " + output_features_path else ""} \
            ~{if defined(output_digital_expression_path) then "--dge " + output_digital_expression_path else ""} \
            ~{if defined(output_digital_expression_summary_path) then "--summary " + output_digital_expression_summary_path else ""} \
            ~{if defined(output_reads_per_cell_file_path) then "--reads-per-cell " + output_reads_per_cell_file_path else ""} \
            ~{if defined(output_read_quality_metrics_path) then "--read-quality-metrics " + output_read_quality_metrics_path else ""} \
            ~{if defined(output_cell_selection_report_path) then "--cell-selection-report " + output_cell_selection_report_path else ""}

        re_gz() {
            local gz_file="$1"
            local tmp_file="${gz_file}.tmp"
            if [[ "${gz_file}" != *.gz ]]; then return; fi
            mv "$gz_file" "$tmp_file"
            gunzip -c "$tmp_file" | gzip -n > "$gz_file"
        }

        ~{if defined(output_digital_expression_path) then "re_gz " + output_digital_expression_path else ""}
        ~{if defined(output_reads_per_cell_file_path) then "re_gz " + output_reads_per_cell_file_path else ""}
        ~{if defined(output_mtx_path) then "re_gz " + output_mtx_path else ""}
        ~{if defined(output_barcodes_path) then "re_gz " + output_barcodes_path else ""}
        ~{if defined(output_features_path) then "re_gz " + output_features_path else ""}
    >>>

    runtime {
        docker: docker
        cpu: cpu
        memory: memory_mb + " MB"
        disks: "local-disk " + disk_gb + " HDD"
        preemptible: preemptible
    }

    output {
        File? output_h5ad = output_h5ad_path
        File? output_mtx = output_mtx_path
        File? output_barcodes = output_barcodes_path
        File? output_features = output_features_path
        File? output_digital_expression = output_digital_expression_path
        File? output_digital_expression_summary = output_digital_expression_summary_path
        File? output_reads_per_cell_file = output_reads_per_cell_file_path
        File? output_read_quality_metrics = output_read_quality_metrics_path
        File? output_cell_selection_report = output_cell_selection_report_path
    }
}
