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

task validate_sam_file {
    input {
        # required inputs
        File input_bam

        # optional inputs
        File? input_bam_idx
        File? fasta
        File? fasta_idx
        File? fasta_dict
        Boolean verbose = false
        Int? max_output
        Array[String] errors_to_ignore = []

        # runtime values
        String docker = "broadinstitute/picard:latest"
        Int cpu = 2
        Int memory_mb = 16384
        Int disk_gb = 10 + ceil(size(input_bam, "GB") + size(fasta, "GB"))
        Int preemptible = 2
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

        java \
            -Xmx${mem_size}m \
            -jar /usr/picard/picard.jar \
            ValidateSamFile \
            --INPUT ~{input_bam} \
            --MODE ~{if verbose then "VERBOSE" else "SUMMARY"} \
            ~{if defined(fasta) then "--REFERENCE_SEQUENCE " + fasta else ""} \
            ~{if defined(max_output) then "--MAX_OUTPUT " + max_output else ""} \
            ~{true="--IGNORE " false="" length(errors_to_ignore) > 0}~{sep=" --IGNORE " errors_to_ignore} \
            --IGNORE MISSING_PLATFORM_VALUE \
            --IGNORE INVALID_VERSION_NUMBER
    >>>

    runtime {
        docker: docker
        cpu: cpu
        memory: memory_mb + " MB"
        disks: "local-disk " + disk_gb + " HDD"
        preemptible: preemptible
    }

    output {
        Boolean done = true
    }
}
