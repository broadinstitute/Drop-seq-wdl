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

task sign_test_qtl {
    input {
        # required inputs
        File cis_qtl
        File unfiltered_qtl

        # optional inputs
        Float? qvalue_threshold
        String validation_stringency = "SILENT"

        # required outputs
        String sign_test_path

        # runtime values
        String docker = "quay.io/broadinstitute/drop-seq_java:current"
        Int cpu = 2
        Int memory_mb = 16384
        Int disk_gb = 10 + ceil(size(cis_qtl, "GB") + size(unfiltered_qtl, "GB"))
        Int preemptible = 2
    }

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

        SignTest \
            -m ${mem_size}m \
            --INPUT ~{cis_qtl} \
            --UNFILTERED_EQTL_FILE ~{unfiltered_qtl} \
            --OUTPUT ~{sign_test_path} \
            ~{if defined(qvalue_threshold) then "--QVALUE_THRESHOLD " + qvalue_threshold else ""} \
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
        File sign_test = sign_test_path
    }
}
