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

task make_intervals {
    input {
        # required inputs
        File sequence_dictionary
        File contig_groups_yaml
        Array[String] ignore_contig_groups

        # required outputs
        String output_prefix

        # runtime values
        String docker = "quay.io/broadinstitute/drop-seq_python:current"
        Int cpu = 2
        Int memory_mb = 4096
        Int disk_gb = 10
        Int preemptible = 2
    }

    # Create one interval file per autosome and one for non-autosomes.
    # Keep intervals in order during globbing by naming the interval list file with a number.
    # Use a custom remove_lines function to remove lines from one file that are in another.
    # Ignore the diff result using "|| true" since it returns 1 when the files differ.
    command <<<
        set -euo pipefail
        set -x

        grep '^@SQ' ~{sequence_dictionary} |
        cut -f 2 |
        sed 's/SN://' \
        > sequence_contigs.txt

        lookup_contig_groups \
            --contig-groups ~{contig_groups_yaml} \
            --group autosome \
        > autosome_contigs.txt

        lookup_contig_groups \
            --contig-groups ~{contig_groups_yaml} \
            --group ~{sep=" " ignore_contig_groups} \
        > excluded_contigs.txt

        remove_contigs() {
            diff --suppress-common-lines --side-by-side $1 $2 | awk '{print $1}' > $3 || true
        }

        add_interval() {
            grep -F $'@SQ\tSN:'"$1"$'\t' ~{sequence_dictionary} |
            cut -f 3 |
            sed 's/LN://' |
            xargs -I {} printf '%s\t1\t%s\t+\t%s\n' "$1" {} "$1" \
            >> "$2"
        }

        remove_contigs sequence_contigs.txt excluded_contigs.txt sequence_contigs_filtered.txt
        remove_contigs autosome_contigs.txt excluded_contigs.txt autosome_contigs_filtered.txt
        remove_contigs sequence_contigs_filtered.txt autosome_contigs_filtered.txt non_autosome_contigs_filtered.txt

        contig_num=0
        for contig in $(cat autosome_contigs_filtered.txt); do
            interval_list=$(printf '~{output_prefix}.%04d.interval_list' "$contig_num")
            cp ~{sequence_dictionary} "$interval_list"
            add_interval "$contig" "$interval_list"
            contig_num=$((contig_num + 1))
        done

        cp ~{sequence_dictionary} ~{output_prefix}.non_autosomes.interval_list
        for contig in $(cat non_autosome_contigs_filtered.txt); do
            add_interval "$contig" ~{output_prefix}.non_autosomes.interval_list
        done
    >>>

    runtime {
        docker: docker
        cpu: cpu
        memory: memory_mb + " MB"
        disks: "local-disk " + disk_gb + " HDD"
        preemptible: preemptible
    }

    output {
        Array[File] interval_files = glob("*.interval_list")
    }
}
