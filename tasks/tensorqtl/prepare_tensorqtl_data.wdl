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

task prepare_tensorqtl_data {
    input {
        # required inputs
        File genotype_bed
        File gene_expression
        File covariates

        # required outputs
        String genotype_matrix_tensorqtl_path
        String gene_expression_tensorqtl_path
        String covariates_tensorqtl_path

        # runtime values
        String docker = "quay.io/broadinstitute/drop-seq_python:current"
        Int cpu = 2
        Int memory_mb = 8192
        Int disk_gb = 10
        Int preemptible = 2
    }

    # Remove genes that are in contigs without any genotypes.
    # Remove donors from covariates if they were previously filtered.
    # Convert genotypes to .bed.parquet so that tensorqtl can parse the file without running out of memory.
    #
    # This task should be removed and the functionality added to PrepareEqtlData.
    # See: https://github.com/broadinstitute/Drop-seq/issues/529
    command <<<
        set -euo pipefail

        prepare_tensorqtl_data \
            --genotype_bed ~{genotype_bed} \
            --phenotypes ~{gene_expression} \
            --covariates ~{covariates} \
            --genotype_out ~{genotype_matrix_tensorqtl_path} \
            --phenotypes_out ~{gene_expression_tensorqtl_path} \
            --covariates_out ~{covariates_tensorqtl_path}

        re_gz() {
            local gz_file=$1
            local tmp_file=$gz_file.tmp
            if [[ $gz_file != *.gz ]]; then return; fi
            mv "$gz_file" "$tmp_file"
            gunzip -c "$tmp_file" | gzip -n > "$gz_file"
        }

        re_gz ~{genotype_matrix_tensorqtl_path}
        re_gz ~{gene_expression_tensorqtl_path}
    >>>

    runtime {
        docker: docker
        cpu: cpu
        memory: memory_mb + " MB"
        disks: "local-disk " + disk_gb + " HDD"
        preemptible: preemptible
    }

    output {
        File genotype_matrix_tensorqtl = genotype_matrix_tensorqtl_path
        File gene_expression_tensorqtl = gene_expression_tensorqtl_path
        File covariates_tensorqtl = covariates_tensorqtl_path
    }
}
