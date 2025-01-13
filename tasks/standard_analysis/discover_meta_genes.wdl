# MIT License
#
# Copyright 2024 Broad Institute
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

task discover_meta_genes {
    input {
        # required inputs
        File alignment_bam
        Boolean write_single_genes

        # optional inputs
        Array[String] locus_function_list = []
        File? known_meta_gene_file
        String? cell_barcode_tag # CB
        String? molecular_barcode_tag # UB
        String metagene_name = "mn"
        String metagene_strand = "ms"
        String metagene_function = "mf"
        File? selected_cell_barcodes
        String validation_stringency = "SILENT"

        # optional outputs
        String? output_bam_path
        String? report_file_path

        # runtime values
        String docker = "us.gcr.io/mccarroll-scrna-seq/drop-seq_private_java:current"
        Int cpu = 2
        Int memory_mb = 16384
        Int disk_gb = 10 + if defined(output_bam_path) then (2 * ceil(size(alignment_bam, "GB"))) else 0
        Int preemptible = 2
    }

    parameter_meta {
        alignment_bam: {
            localization_optional: true
        }
    }

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
        mem_size=$(awk "BEGIN {print int($mem_size * 7 / 8)}")

        DiscoverMetaGenes \
            -m ${mem_size}m \
            --WRITE_SINGLE_GENES ~{write_single_genes} \
            --INPUT ~{alignment_bam} \
            ~{sep=" " prefix("--LOCUS_FUNCTION_LIST ", locus_function_list)} \
            ~{if defined(known_meta_gene_file) then "--KNOWN_META_GENE_FILE " + known_meta_gene_file else ""} \
            ~{if defined(cell_barcode_tag) then "--CELL_BARCODE_TAG " + cell_barcode_tag else ""} \
            ~{if defined(molecular_barcode_tag) then "--MOLECULAR_BARCODE_TAG " + molecular_barcode_tag else ""} \
            --METAGENE_NAME ~{metagene_name} \
            --METAGENE_STRAND ~{metagene_strand} \
            --METAGENE_FUNCTION ~{metagene_function} \
            ~{if defined(selected_cell_barcodes) then "--CELL_BC_FILE " + selected_cell_barcodes else ""} \
            ~{if defined(output_bam_path) then "--OUTPUT " + output_bam_path else ""} \
            ~{if defined(report_file_path) then "--REPORT " + report_file_path else ""} \
            --VALIDATION_STRINGENCY ~{validation_stringency}
    >>>

    runtime {
        docker: docker
        cpu: cpu
        memory: memory_mb + " MB"
        disks: "local-disk " + disk_gb + " HDD"
        preemptible: preemptible
    }

    output {
        File? output_bam = output_bam_path
        File? report_file = report_file_path
    }
}
