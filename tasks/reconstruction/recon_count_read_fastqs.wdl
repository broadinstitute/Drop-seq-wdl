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

task recon_count_read_fastqs {
    input {
        # Required inputs
        String bcl
        File find_fastqs_metadata_csv
        Array[File] find_fastqs_fastqs_txts
        Array[File] fastqs

        # Optional inputs
        Float? downsampling_level
        String? r1_filter
        String? r2_filter
        File? recon_count_read_fastqs_jl
        Float heap_fraction = 0.75

        # Runtime values
        String docker = "quay.io/broadinstitute/macosko-pipelines_reconstruction:current"
        Int cpu = 1 + ceil(length(fastqs) / 2)
        Int memory_gb = 16
        Int disk_gb = 10 + 2 * ceil(size(fastqs, "GB"))
        # This job takes a long time to run, and seems to preempt often enough to exhaust the premption count anyway
        Int preemptible = 0
    }

    Array[File] in_dir_files = flatten([
        [find_fastqs_metadata_csv],
        find_fastqs_fastqs_txts,
        fastqs
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

        mkdir -p fastqs/~{bcl}

        for in_dir_file in ~{sep=" " in_dir_files}; do
            ln -s $in_dir_file fastqs/~{bcl}/
        done

        mkdir -p out_dir

        for f in \
            recon-count_read-fastqs.jl \
            logging.jl \
            find-fastqs.jl \
            bead-info.jl \
            metadata.jl \
            learn-bead-types.jl \
            data-frame.jl \
            read-fastqs.jl \
            count-reads.jl \
            metadata.jl \
        ; do
            wget https://raw.githubusercontent.com/kshakir/Macosko-Pipelines/refs/heads/ks_recon_count_scatter/reconstruction/$f
        done

        JULIA_DEPOT_PATH=${TMPDIR:-}:/root/.julia \
            julia \
            --threads ~{cpu} \
            --heap-size-hint ${mem_size}M \
            recon-count_read-fastqs.jl \
            fastqs/~{bcl} \
            out_dir \
            ~{if defined(downsampling_level) then "--downsampling_level " + downsampling_level else ""} \
            ~{if defined(r1_filter) then "--R1_filter " + r1_filter else ""} \
            ~{if defined(r2_filter) then "--R2_filter " + r2_filter else ""}
    >>>

    runtime {
        docker: docker
        cpu: cpu
        memory: memory_gb + " GB"
        disks: "local-disk " + disk_gb + " HDD"
        preemptible: preemptible
    }

    output {
        File reads_df_csv_gz = glob("out_dir/reads_df*.csv.gz")[0]
        File metadata_csv = glob("out_dir/metadata*.csv")[0]
        Array[File] rpsb_csv_gzs = glob("out_dir/rpsb*.csv.gz")
        File? null_file = "expected_missing_file"
        Array[File] reads_per_umi_csvs = glob("out_dir/reads_per_umi*.csv")
        Array[File] readumi_per_sb1_csv_gzs = glob("out_dir/readumi_per_sb1*.csv.gz")
        Array[File] readumi_per_sb2_csv_gzs = glob("out_dir/readumi_per_sb2*.csv.gz")
        File? reads_per_umi_csv = if length(reads_per_umi_csvs) > 0 then reads_per_umi_csvs[0] else null_file
        File? readumi_per_sb1_csv_gz = if length(readumi_per_sb1_csv_gzs) > 0 then readumi_per_sb1_csv_gzs[0] else null_file
        File? readumi_per_sb2_csv_gz = if length(readumi_per_sb2_csv_gzs) > 0 then readumi_per_sb2_csv_gzs[0] else null_file
    }
}
