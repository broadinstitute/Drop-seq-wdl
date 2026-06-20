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

task recon_count_find_fastqs {
    input {
        # Required inputs
        String bcl
        String recon_name
        Array[File] fastqs

        # Optional inputs
        String? regex
        File? recon_count_find_fastqs_jl
        Float heap_fraction = 0.75

        # Runtime values
        String docker = "quay.io/broadinstitute/macosko-pipelines_reconstruction:current"
        Int cpu = 2
        Int memory_gb = 16
        Int disk_gb = 10 + ceil(size(fastqs, "GB"))
        # This job takes a long time to run, and seems to preempt often enough to exhaust the premption count anyway
        Int preemptible = 0
    }

    String parent_recon_count_dir = "recon-count"
    String out_dir = parent_recon_count_dir + "/" + bcl + "/" + recon_name

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

        for fastq in ~{sep=" " fastqs}; do
            ln -s $fastq fastqs/~{bcl}/
        done

        mkdir -p ~{out_dir}

        for f in \
            recon-count_find-fastqs.jl \
            logging.jl \
            find-fastqs.jl \
            bead-info.jl \
            learn-bead-types.jl \
            metadata.jl \
        ; do
            wget https://raw.githubusercontent.com/kshakir/Macosko-Pipelines/refs/heads/ks_recon_count_scatter/reconstruction/$f
        done

        JULIA_DEPOT_PATH=${TMPDIR:-}:/root/.julia \
            julia \
            --threads ~{cpu} \
            --heap-size-hint ${mem_size}M \
            recon-count_find-fastqs.jl \
            fastqs/~{bcl} \
            ~{out_dir} \
            ~{if defined(regex) then "--regex " + regex else ""}
    >>>

    runtime {
        docker: docker
        cpu: cpu
        memory: memory_gb + " GB"
        disks: "local-disk " + disk_gb + " HDD"
        preemptible: preemptible
    }

    output {
        File filepaths_pdf = out_dir + "/filepaths.pdf"
        File metadata_csv = out_dir + "/metadata.csv"
        Array[File] fastqs_txts = glob(out_dir + "/fastqs*.txt")
    }
}
