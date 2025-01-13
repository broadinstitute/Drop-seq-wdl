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

task split_bam_by_cell {
    input {
        # required inputs
        File input_bam
        String split_tag # CB
        Int target_bam_size_gb

        # optional inputs
        String? output_slug_raw
        String? output_slug_regex
        String validation_stringency = "SILENT"

        # required outputs
        String output_bams_pattern

        # optional outputs
        String? output_list_path
        String? output_report_path
        String? output_manifest_path

        # runtime values
        String docker = "us.gcr.io/mccarroll-scrna-seq/drop-seq_private_java:current"
        Int cpu = 2
        Int memory_mb = 4096
        Int disk_gb = 10 + (2 * ceil(size(input_bam, "GB")))
        Int preemptible = 2
    }

    parameter_meta {
        input_bam: {
            localization_optional: true
        }
    }

    Int num_outputs = ceil(size(input_bam, "GB") / target_bam_size_gb)
    String output_slug_glob = if defined(output_slug_regex) then select_first([output_slug_regex]) else "__SPLITNUM__"

    command <<<
        set -euo pipefail

        mem_unit=${MEM_UNIT%?}
        if [[ $mem_unit == "M" ]]; then
            mem_size=$(awk "BEGIN {print int($MEM_SIZE)}")
        elif [[ $mem_unit == "G" ]]; then
            mem_size=$(awk "BEGIN {print int($MEM_SIZE * 1024)}")
        else
            echo "Unsupported memory unit: $MEM_UNIT" 1>&2
            exit 1
        fi
        mem_size=$(awk "BEGIN {print int($mem_size * 7 / 8)}")

        SplitBamByCell \
            -m ${mem_size}m \
            --INPUT ~{input_bam} \
            --SPLIT_TAG ~{split_tag} \
            --NUM_OUTPUTS ~{num_outputs} \
            --OUTPUT ~{output_bams_pattern} \
            ~{if defined(output_slug_raw) then "--OUTPUT_SLUG " + output_slug_raw else ""} \
            ~{if defined(output_list_path) then "--OUTPUT_LIST " + output_list_path else ""} \
            ~{if defined(output_report_path) then "--REPORT " + output_report_path else ""} \
            ~{if defined(output_manifest_path) then "--OUTPUT_MANIFEST " + output_manifest_path else ""} \
            --VALIDATION_STRINGENCY ~{validation_stringency}
    >>>

    runtime {
        docker: docker
        cpu: cpu
        memory: memory_mb + " MB"
        disks: "local-disk " + disk_gb + " HDD"
        preemptible: preemptible
    }

    output {
        Array[File] output_bams = glob(sub(output_bams_pattern, output_slug_glob, '\\*'))
        File? output_list = output_list_path
        File? output_report = output_report_path
        File? output_manifest = output_manifest_path
    }
}
