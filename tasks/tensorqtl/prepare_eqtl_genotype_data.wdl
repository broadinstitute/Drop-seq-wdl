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

task prepare_eqtl_genotype_data {
    input {
        # required inputs
        File vcf
        File vcf_idx
        File donor_list

        # optional inputs
        File? interval_file
        Int? gq_threshold
        Float? fraction_samples_passing
        Float? hwe_pvalue
        Float? maf
        Array[String] ignored_chromosomes = []
        String validation_stringency = "SILENT"

        # required outputs
        String genotype_bed_path

        # runtime values
        String docker = "quay.io/broadinstitute/drop-seq_java:current"
        Int cpu = 2
        Int memory_mb = 16384
        Int disk_gb = 20
        Int preemptible = 2
    }

    parameter_meta {
        vcf: {
            localization_optional: true
        }
        vcf_idx: {
            localization_optional: true
        }
    }

    Array[String] ignored_chromosomes_list = if (length(ignored_chromosomes) > 0) then flatten([["null"], ignored_chromosomes]) else []

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

        PrepareEqtlGenotypeData \
            -m ${mem_size}m \
            --INPUT_VCF ~{vcf} \
            --SAMPLE_FILE ~{donor_list} \
            ~{if defined(interval_file) then "--INTERVAL_FILE " + interval_file else "" } \
            ~{if defined(gq_threshold) then "--GQ_THRESHOLD " + gq_threshold else ""} \
            ~{if defined(fraction_samples_passing) then "--FRACTION_SAMPLES_PASSING " + fraction_samples_passing else ""} \
            ~{if defined(hwe_pvalue) then "--HWE_PVALUE " + hwe_pvalue else ""} \
            ~{if defined(maf) then "--MAF " + maf else ""} \
            ~{true="--IGNORED_CHROMOSOMES " false="" length(ignored_chromosomes_list) > 0}~{sep=" --IGNORED_CHROMOSOMES " ignored_chromosomes_list} \
            --GENOTYPE_BED ~{genotype_bed_path} \
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
        File genotype_bed = genotype_bed_path
    }
}
