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

task untar {
    input {
        # required inputs
        String target_directory
        File tar_file

        # runtime values
        # Use old tar since builds were changed to use an `openat2` call that isn't available on old systems.
        # - https://github.com/praiskup/tar/commit/75b03fdff48916bd0654677ed21379bdb0db016d
        # See also: lots of folks tripping over `Cannot open: Function not implemented` and
        # `Cannot mkdir: Function not implemented`
        # - https://lists.openembedded.org/g/openembedded-core/topic/patch_v2_3_7_pseudo_fix/118204632
        # - https://github.com/orbstack/orbstack/issues/2588
        # - https://github.com/Xpra-org/repo-build-scripts/issues/15
        # - https://github.com/abiosoft/colima/issues/1613
        # - https://github.com/tonistiigi/binfmt/issues/285
        String docker = "ubuntu:24.04"
        Int cpu = 2
        Int memory_mb = 4096
        Int disk_gb = 10
        Int preemptible = 0
    }

    command <<<
        set -euo pipefail

        mkdir -p ~{target_directory}
        tar -C ~{target_directory} -xvf ~{tar_file}
    >>>

    runtime {
        docker: docker
        cpu: cpu
        memory: memory_mb + " MB"
        disks: "local-disk " + disk_gb + " HDD"
        preemptible: preemptible
    }

    output {
        Boolean done = true
    }
}
