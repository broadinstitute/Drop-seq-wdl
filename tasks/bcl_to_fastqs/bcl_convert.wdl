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

task bcl_convert {
    input {
        # Required inputs
        File sample_sheet
        String input_dir
        String output_dir
        String docker

        # Optional inputs
        Array[File] input_tars = []
        Boolean force = true
        Int? bcl_only_lane
        Boolean bcl_only_matched_reads = false
        Boolean strict_mode = false
        Boolean first_tile_only = false
        Boolean bcl_sampleproject_subdirectories = false
        Boolean sample_name_column_enable = false
        Int fastq_gzip_compression_level = 1
        Boolean bcl_convert_clean = false

        # Runtime values
        Int cpu = 2
        Int memory_gb = 32
        Int disk_gb = 10 + 3 * ceil(size(input_tars, "GB"))
        Int preemptible = 0
    }

    command <<<
        set -euo pipefail

        for input_tar in ~{sep=" " input_tars}; do
            tar -xvf ${input_tar}
        done

        ~{if bcl_convert_clean then "rm -rf " + output_dir else ""}
        ~{if force then "mkdir -p " + output_dir else ""}

        bcl-convert \
            --bcl-input-directory ~{input_dir} \
            --output-directory ~{output_dir} \
            --sample-sheet ~{sample_sheet} \
            ~{if force then "--force" else ""} \
            ~{"--bcl-only-lane " + bcl_only_lane} \
            --bcl-only-matched-reads ~{bcl_only_matched_reads} \
            --strict-mode ~{strict_mode} \
            --first-tile-only ~{first_tile_only} \
            --bcl-sampleproject-subdirectories ~{bcl_sampleproject_subdirectories} \
            --sample-name-column-enable ~{sample_name_column_enable} \
            --fastq-gzip-compression-level ~{fastq_gzip_compression_level} \
            --bcl-num-conversion-threads ~{cpu} \
            --bcl-num-compression-threads ~{cpu} \
            --bcl-num-decompression-threads ~{ceil(cpu / 2)}

        find ~{output_dir} -name '*.fastq.gz' | sort > fastqs.txt
    >>>

    runtime {
        docker: docker
        cpu: cpu
        memory: memory_gb + " GB"
        disks: "local-disk " + disk_gb + " HDD"
        preemptible: preemptible
    }

    # Glob the fastqs if possible. It may fail if the output_dir is outside the container and the glob functionality
    # tries to hardlink across filesystems.
    # Also list the local fastqs from the generated text file which may be absolute paths.
    output {
        Array[File] glob_fastqs = flatten([glob(output_dir + "/*.fastq.gz"), glob(output_dir + "/*/*.fastq.gz")])
        Array[String] local_fastqs = read_lines("fastqs.txt")
        File demultiplex_stats = output_dir + "/Reports/Demultiplex_Stats.csv"
        File index_hopping_counts = output_dir + "/Reports/Index_Hopping_Counts.csv"
        File top_unknown_barcodes = output_dir + "/Reports/Top_Unknown_Barcodes.csv"
    }
}
