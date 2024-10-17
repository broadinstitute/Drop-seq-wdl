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

# Ported from: LaunchScRnaCellSelection.makeCriteriaLabel()

task make_cell_selection_args {
    input {
        # optional inputs
        Int? min_umis_per_cell
        Int? max_umis_per_cell
        Int? max_rbmt_per_cell
        Float? min_intronic_per_cell
        Float? max_intronic_per_cell
        Float? efficiency_threshold_log10
        String? call_stamps_method
        Boolean is_10x = true

        # runtime values
        String docker = "ubuntu"
        Int cpu = 2
        Int memory_mb = 1024
        Int disk_gb = 10
        Int preemptible = 2
    }

    command <<<
        set -euo pipefail

        make_criteria_label() {
            local min_umis_per_cell="~{min_umis_per_cell}"
            local max_umis_per_cell="~{max_umis_per_cell}"
            local max_rbmt_per_cell="~{max_rbmt_per_cell}"
            local min_intronic_per_cell="~{min_intronic_per_cell}"
            local max_intronic_per_cell="~{max_intronic_per_cell}"
            local efficiency_threshold_log10="~{efficiency_threshold_log10}"
            local call_stamps_method="~{call_stamps_method}"
            local is_10x="~{is_10x}"
            local criteria_label

            if [[ -n "$min_umis_per_cell" || -n "$max_umis_per_cell" || -n "$max_rbmt_per_cell" || -n "$min_intronic_per_cell" || -n "$max_intronic_per_cell" ]]; then
                criteria_label=""
                if [[ -n "$min_umis_per_cell" || -n "$max_umis_per_cell" ]]; then
                    criteria_label="${criteria_label}$(printf '_umi_%s-%s' "${min_umis_per_cell:-1}" "${max_umis_per_cell:-Inf}")"
                fi

                if [[ -n "$min_intronic_per_cell" || -n "$max_intronic_per_cell" ]]; then
                    criteria_label="${criteria_label}$(printf '_intronic_%.3f-%.3f' "${min_intronic_per_cell:-0}" "${max_intronic_per_cell:-1}")"
                fi

                if [[ -n "$max_rbmt_per_cell" ]]; then
                    criteria_label="${criteria_label}$(printf '_rbmt_%.3f' "$max_rbmt_per_cell")"
                fi

                # strip leading underscore
                criteria_label="${criteria_label:1}"
            elif [[ -n "$call_stamps_method" ]]; then
                criteria_label="$call_stamps_method"
            else
                criteria_label="auto"
            fi

            if [[ -n "$efficiency_threshold_log10" ]]; then
                criteria_label="${criteria_label}$(printf '_eff_%.3f' "$efficiency_threshold_log10")"
            fi

            if [[ "$is_10x" == true ]]; then
                criteria_label="${criteria_label}_10X"
            fi

            echo "${criteria_label}" > criteria_label
        }

        make_criteria_label
    >>>

    runtime {
        docker: docker
        cpu: cpu
        memory: memory_mb + " MB"
        disks: "local-disk " + disk_gb + " HDD"
        preemptible: preemptible
    }

    output {
        String criteria_label = read_string("criteria_label")
    }
}
