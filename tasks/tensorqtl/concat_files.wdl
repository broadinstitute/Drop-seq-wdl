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

task concat_files {
    input {
        # required inputs
        Array[File] files

        # required outputs
        String out_path

        # optional inputs
        Int header_count = 0

        # runtime values
        String docker = "ubuntu"
        Int cpu = 2
        Int memory_mb = 4096
        Int disk_gb = 10 + (3 * ceil(size(files, "GB")))
        Int preemptible = 2
    }

    Boolean gzip = basename(out_path) != basename(out_path, ".gz")
    String unzip_command = if gzip then "gunzip -c" else "cat"
    String zip_command = if gzip then "gzip -n" else "cat"

    # Ignore the cat/gunzip result using "|| true" since it returns 141 when only partially completed.
    command <<<
        set -euo pipefail
        set -x

        if [[ ~{header_count} -gt 0 ]]; then
            ~{unzip_command} ~{files[0]} | head -n ~{header_count} | ~{zip_command} > ~{out_path} || true
        else
            touch ~{out_path}
        fi

        for i in ~{sep=" " files}; do
            ~{unzip_command} $i | tail -n +~{header_count+1} | ~{zip_command} >> ~{out_path} || true
        done

        re_gz() {
            local gz_file=$1
            local tmp_file=$gz_file.tmp
            if [[ $gz_file != *.gz ]]; then return; fi
            mv "$gz_file" "$tmp_file"
            gunzip -c "$tmp_file" | gzip -n > "$gz_file"
        }

        re_gz ~{out_path}
    >>>

    runtime {
        docker: docker
        cpu: cpu
        memory: memory_mb + " MB"
        disks: "local-disk " + disk_gb + " HDD"
        preemptible: preemptible
    }

    output {
        File out = out_path
    }
}
