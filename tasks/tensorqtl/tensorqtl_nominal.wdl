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

task tensorqtl_nominal {
    input {
        # required inputs
        File genotype_matrix
        File gene_expression

        # optional inputs
        File? covariates
        Int? cis_window_size
        Float? maf_threshold
        Int seed = 777

        # required outputs
        String output_prefix

        # runtime values
        String docker = # Same as latest tag as of April 2025 containing v1.0.9. No tags after v1.0.8.
            "gcr.io/broad-cga-francois-gtex/tensorqtl@sha256:f6efb9e592eb32c46cb75070be2769b34381d60cbb2709d2885771324abfe32a"
        Int cpu = 2
        Int memory_mb = 32768
        Int disk_gb = 20
        Int preemptible = 2
        String gpu_type = "nvidia-tesla-p100"
        Int gpu_count = 1
        String zones = "us-central1-c us-central1-f" # Restrict to zones in us-central1 with p100 gpus
    }

    # Use "python3 -m tensorqtl" to avoid "TypeError: 'module' object is not callable" at end of run.
    # Touch all the .parquet files to set the minimal zip file date. Allows the zip outputs to be cached.
    # The parquet files are already compressed, so use zip -0 to avoid recompressing them.
    command <<<
        set -euo pipefail

        python3 -m tensorqtl \
            ~{genotype_matrix} \
            ~{gene_expression} \
            ~{output_prefix} \
            --mode cis_nominal \
            ~{if defined(covariates) then "--covariates " + covariates else ""} \
            ~{if defined(cis_window_size) then "--window " + cis_window_size else ""} \
            ~{if defined(maf_threshold) then "--maf_threshold " + maf_threshold else ""} \
            --seed ~{seed}

        touch -t 198001010000 ~{output_prefix}.cis_qtl_pairs.*.parquet

        zip -X -0 ~{output_prefix}.cis_qtl_pairs.zip ~{output_prefix}.cis_qtl_pairs.*.parquet
    >>>

    runtime {
        docker: docker
        cpu: cpu
        memory: memory_mb + " MB"
        disks: "local-disk " + disk_gb + " HDD"
        preemptible: preemptible
        gpuType: gpu_type
        gpuCount: gpu_count
        zones: zones
    }

    output {
        Array[File] cis_qtl_pairs = glob(output_prefix + ".cis_qtl_pairs.*.parquet")
        File cis_qtl_pairs_zip = output_prefix + ".cis_qtl_pairs.zip"
    }
}
