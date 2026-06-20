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

task validate_recon_inputs {
    input {
        # Required inputs
        String bcl
        String sample_name

        # Optional inputs
        Int? lane
        Int? r1_barcodes
        Int? r2_barcodes
        Float? downsampling_level

        # Runtime values
        String docker = "python:3.13-slim"
        Int cpu = 1
        Int memory_gb = 2
        Int disk_gb = 10
        Int preemptible = 0
    }

    # Tags and validation are based on an example notebook provided by the Macosko lab
    String lane_tag = if defined(lane) && lane > 0 then "-" + lane else ""
    String downsampling_tag =
        if defined(downsampling_level) && downsampling_level < 1 then "_p-" + downsampling_level else ""
    String r1_barcodes_tag = if defined(r1_barcodes) && r1_barcodes > 0 then "_bc1-" + r1_barcodes else ""
    String r2_barcodes_tag = if defined(r2_barcodes) && r2_barcodes > 0 then "_bc2-" + r2_barcodes else ""

    command <<<
        set -euo pipefail

        python <<EOF
        import re
        sample_id = re.sub(r"[^a-zA-Z0-9_-]", "_", "~{sample_name}")
        assert not re.search(r"\s", "~{bcl}")
        assert not re.search(r"\s", sample_id)
        ~{if defined(lane) then "assert 0 <= " + lane + " <= 8 # 0 means all lanes" else ""}
        ~{if defined(downsampling_level) then "assert 0 < " + downsampling_level + " <= 1" else ""}
        with open("sample_id.txt", "w") as f:
            f.write(sample_id + "\n")
        EOF
    >>>

    runtime {
        docker: docker
        cpu: cpu
        memory: memory_gb + " GB"
        disks: "local-disk " + disk_gb + " HDD"
        preemptible: preemptible
    }

    output {
        String index = read_string("sample_id.txt")
        String recon_name = index + lane_tag + downsampling_tag + r1_barcodes_tag + r2_barcodes_tag
    }
}
