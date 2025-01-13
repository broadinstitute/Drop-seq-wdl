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

# Ported from: CbrbStepBuilder.makeAnalysisTag()
#
# Create both of these files:
#
# # yaml template for running CellBender remove-background with Google Life Sciences API
# actions:
#   - containerName: remove-background
#     commands:
#       - cd /local-disk && cellbender remove-background --cuda --input /local-disk --output /local-disk/<library_name>.h5 --final-elbo-fail-fraction 0.1 --num-training-tries 3
#       - cd /local-disk && cellbender remove-background --cuda --input /local-disk --output /local-disk/__library__.h5 __other_args__
#
# Other args is these 5 args, plus cbrb_other_args:
# --expected-cells <expected_cells>
# --total-droplets-included <total_droplets_included>
# --num-training-tries <num_training_tries>
# --final-elbo-fail-fraction <final_elbo_fail_fraction>
# --learning-rate <learning_rate>
#
# commandLine: 'LaunchScRnaCbrb MANIFEST=<alignment_dir>/<library_name>.<locus_function_label>.cbrb.manifest.yaml
#  LOCUS_FUNCTION_PROPERTIES=<alignment_dir>/<library_name>.locusFunction.properties.yaml
#  PICARD_DIRECTORY=<picard_dir> DROPSEQ_TOOLS_DIRECTORY=<dropseq_tools_dir>
#  PROJECT_METADATA=<project_metadata_yaml>
#  PROJECT=<dropseq_project> WORKFLOW_VERSION=1234567890 NOTIFICATION_EMAIL=<user>@broadinstitute.org
#  JMS_SERVER=<jms_server> JMS_QUEUE=<jms_queue> SENDER=<user>
#  TMP_DIR=<tmp_dir>    UNIQUIFY_DIRECTORIES=false IGNORE_WARNINGS=false   VALIDATION_STRINGENCY=SILENT       '
task make_cbrb_args {
    input {
        # required inputs
        String workflow_command_line
        String raw_digital_expression_path
        String library_name

        # optional inputs
        Int? expected_cells
        Int? total_droplets_included
        Int? num_training_tries
        Float? final_elbo_fail_fraction
        Float? learning_rate
        String cbrb_other_args = ""

        # required outputs
        String cbrb_gls_yaml_path
        String cbrb_properties_yaml_path

        # runtime values
        String docker = "ubuntu"
        Int cpu = 2
        Int memory_mb = 1024
        Int disk_gb = 10
        Int preemptible = 2
    }

    command <<<
        set -euo pipefail

        touch cbrb_args
        ~{if defined(expected_cells) then "printf ' --expected-cells " + expected_cells + "' >> cbrb_args" else ""}
        ~{if defined(total_droplets_included) then "printf ' --total-droplets-included " + total_droplets_included + "' >> cbrb_args" else ""}
        ~{if defined(num_training_tries) then "printf ' --num-training-tries " + num_training_tries + "' >> cbrb_args" else ""}
        ~{if defined(final_elbo_fail_fraction) then "printf ' --final-elbo-fail-fraction " + final_elbo_fail_fraction + "' >> cbrb_args" else ""}
        ~{if defined(learning_rate) then "printf ' --learning-rate " + learning_rate + "' >> cbrb_args" else ""}
        # strip leading space
        sed -i 's/^ //' cbrb_args

        make_analysis_tag() {
            local expected_cells="~{expected_cells}"
            local total_droplets_included="~{total_droplets_included}"
            local learning_rate="~{learning_rate}"
            local has_other_args="~{cbrb_other_args != ""}"
            local analysis_directory_name

            if [[ -z "$expected_cells" && -z "$total_droplets_included" && -z "$learning_rate" ]]; then
                analysis_directory_name="auto"
            else
                local analysis_directory_name=""

                if [[ -n "$expected_cells" ]]; then
                    analysis_directory_name="${analysis_directory_name}$(printf '_ec-%d' "$expected_cells")"
                fi

                if [[ -n "$total_droplets_included" ]]; then
                    analysis_directory_name="${analysis_directory_name}$(printf '_tdi-%d' "$total_droplets_included")"
                fi

                if [[ -n "$learning_rate" ]]; then
                    analysis_directory_name="${analysis_directory_name}$(printf '_lr-%s' "$learning_rate")"
                fi

                # strip leading underscore
                analysis_directory_name="${analysis_directory_name:1}"
            fi

            if [[ "$has_other_args" == true ]]; then
                analysis_directory_name="${analysis_directory_name}_o"
            fi

            echo "${analysis_directory_name}" > analysis_tag
        }

        make_analysis_tag

        cat > ~{cbrb_gls_yaml_path} <<EOF
        actions:
          - containerName: remove-background
            commands:
              - cellbender remove-background --cuda --input ~{raw_digital_expression_path} --output ~{library_name}.h5 $(cat cbrb_args)
        EOF

        cat > ~{cbrb_properties_yaml_path} <<EOF
        commandLine: '~{workflow_command_line}'
        EOF
    >>>

    runtime {
        docker: docker
        cpu: cpu
        memory: memory_mb + " MB"
        disks: "local-disk " + disk_gb + " HDD"
        preemptible: preemptible
    }

    output {
        String analysis_tag = read_string("analysis_tag")
        String cbrb_args = read_string("cbrb_args")
        File cbrb_gls_yaml = cbrb_gls_yaml_path
        File cbrb_properties_yaml = cbrb_properties_yaml_path
    }
}
