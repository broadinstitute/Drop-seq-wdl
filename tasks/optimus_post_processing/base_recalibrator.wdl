# MIT License
#
# Copyright 2025 Broad Institute
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

task base_recalibrator {
    input {
        # required inputs
        Array[File] input_bams
        File fasta
        File fasta_idx
        File fasta_dict
        Array[File] known_sites_vcfs
        Array[File] known_sites_vcf_idxs

        # optional inputs
        File? intervals

        # required outputs
        String output_file_path

        # runtime values
        String docker = "broadinstitute/gatk:latest"
        Int cpu = 2
        Int memory_mb = 32768
        Int disk_gb = 10
        Int preemptible = 2
    }

    parameter_meta {
        input_bams: {
            localization_optional: true
        }
        fasta: {
            localization_optional: true
        }
        fasta_idx: {
            localization_optional: true
        }
        fasta_dict: {
            localization_optional: true
        }
        known_sites_vcfs: {
            localization_optional: true
        }
        known_sites_vcf_idxs: {
            localization_optional: true
        }
    }

    # h/t for prefix workaround: https://github.com/broadinstitute/cromwell/issues/5092#issuecomment-515872319
    command <<<
        set -euo pipefail

        mem_unit=$(echo "${MEM_UNIT:-}" | cut -c 1)
        if [[ $mem_unit == "M" ]]; then
            mem_size=$(awk "BEGIN {print int($MEM_SIZE)}")
        elif [[ $mem_unit == "G" ]]; then
            mem_size=$(awk "BEGIN {print int($MEM_SIZE * 1024)}")
        else
            mem_size=$(free -m | awk '/^Mem/ {print $2}')
        fi
        mem_size=$(awk "BEGIN {print int($mem_size * 7 / 8)}")

        gatk \
            --java-options "-Xmx${mem_size}m" \
            BaseRecalibrator \
            ~{true="--input " false="" length(input_bams) > 0}~{sep=" --input " input_bams} \
            --reference ~{fasta} \
            ~{true="--known-sites " false="" length(known_sites_vcfs) > 0}~{sep=" --known-sites " known_sites_vcfs} \
            ~{if defined(intervals) then "--intervals " + intervals else ""} \
            --output ~{output_file_path}
    >>>

    runtime {
        docker: docker
        cpu: cpu
        memory: memory_mb + " MB"
        disks: "local-disk " + disk_gb + " HDD"
        preemptible: preemptible
    }

    output {
        File output_file = output_file_path
    }
}
