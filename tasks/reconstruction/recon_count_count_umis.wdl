# MIT License
#
# Copyright 2026 Broad Institute
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

task recon_count_count_umis {
    input {
        # Required inputs
        String recon_name
        File find_fastqs_filepaths_pdf
        File compute_whitelists_elbows_pdf
        File compute_whitelists_metadata_csv
        Array[File] remove_chimeras_reads_counts_csv_gzs
        Array[File] remove_chimeras_umi_counts_csv_gzs
        Array[File] remove_chimeras_umi_df_csv_gzs
        Array[File] remove_chimeras_metadata_csvs
        Array[File] read_fastqs_n_metadata_csvs

        # Optional inputs
        Float? downsampling_level
        Int? r1_barcodes
        Int? r2_barcodes
        File? recon_count_count_umis_jl
        Float heap_fraction = 0.75

        # Runtime values
        String docker = "quay.io/broadinstitute/macosko-pipelines_reconstruction:current"
        Int cpu = 4
        Int memory_gb = 16
        Int disk_gb = 10 + 2 * ceil(size(flatten([
            remove_chimeras_reads_counts_csv_gzs,
            remove_chimeras_umi_counts_csv_gzs,
            remove_chimeras_umi_df_csv_gzs,
            remove_chimeras_metadata_csvs,
            read_fastqs_n_metadata_csvs
        ]), "GB"))
        Int preemptible = 0
    }

    # compute_whitelists_metadata_csv is not included because it will be renamed
    Array[File] in_dir_files = flatten([
        [find_fastqs_filepaths_pdf, compute_whitelists_elbows_pdf],
        remove_chimeras_reads_counts_csv_gzs,
        remove_chimeras_umi_counts_csv_gzs,
        remove_chimeras_umi_df_csv_gzs,
        remove_chimeras_metadata_csvs,
        read_fastqs_n_metadata_csvs
    ])

    # The JULIA_DEPOT_PATH is set to use the current user's depot via the empty string, then fall back to the root
    # user's depot. The docker image is set up to use the root user's depot, so this is a workaround to allow running
    # on singularity that runs as non-root.
    # https://docs.julialang.org/en/v1/manual/environment-variables/#JULIA_DEPOT_PATH
    # Instead of writing to ~/.julia, try the TMPDIR first, then fall back to the empty string.
    # Some sort of permissions, caching, or other issue is causing julia to recompile _everything_ to ~/.julia.
    # Meanwhile, the temporary filesystem containing ~/ has only 16MB of space in singularity.
    # https://github.com/apptainer/apptainer/issues/1313
    # Set the --heap-size-hint as heap size settings are only soft hints and the julia programs were running out of
    # memory with exit code 137.
    # https://discourse.julialang.org/t/heap-size-hint-usage-recommendations/98697
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
        mem_size=$(awk "BEGIN {print int($mem_size * ~{heap_fraction})}")

        mkdir -p in_dir

        ln -s ~{compute_whitelists_metadata_csv} in_dir/metadata.compute_whitelists.csv
        for in_dir_file in ~{sep=" " in_dir_files}; do
            ln -s $in_dir_file in_dir/
        done

        mkdir -p out_dir
        mkdir -p out_pdf

        for f in \
            recon-count_count-umis.jl \
            logging.jl \
            metadata.jl \
            bead-info.jl \
            data-frame.jl \
            count-umis.jl \
            filter-connections.jl \
            write-outputs.jl \
        ; do
            wget https://raw.githubusercontent.com/kshakir/Macosko-Pipelines/refs/heads/ks_recon_count_scatter/reconstruction/$f
        done

        JULIA_DEPOT_PATH=${TMPDIR:-}:/root/.julia \
            julia \
            --threads ~{cpu} \
            --heap-size-hint ${mem_size}M \
            recon-count_count-umis.jl \
            in_dir \
            out_dir \
            ~{if defined(downsampling_level) then "--downsampling_level " + downsampling_level else ""} \
            ~{if defined(r1_barcodes) then "--R1_barcodes " + r1_barcodes else ""} \
            ~{if defined(r2_barcodes) then "--R2_barcodes " + r2_barcodes else ""}

        cp out_dir/QC.pdf out_pdf/~{recon_name}.QC.pdf
    >>>

    runtime {
        docker: docker
        cpu: cpu
        memory: memory_gb + " GB"
        disks: "local-disk " + disk_gb + " HDD"
        preemptible: preemptible
    }

    output {
        File matrix_csv_gz = "out_dir/matrix.csv.gz"
        Float matrix_gb = size(matrix_csv_gz, "GB")
        File qc_pdf = "out_pdf/" + recon_name + ".QC.pdf"
        # Capture anything produced by count-umis.jl
        Array[File] count_umis_outputs = glob("out_dir/*")
    }
}
