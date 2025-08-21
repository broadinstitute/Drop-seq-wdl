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

task donor_assignment_qc {
    input {
        # required inputs
        File doublet_likelihood_file
        File dge_file
        File dge_summary_file
        File expected_samples_file
        File likelihood_summary_file
        File dge_raw_summary_file
        File reads_per_cell_file
        String exp_name

        # optional inputs
        File? census_file

        # required outputs
        String out_summary_stats_file_path
        String out_donor_to_cell_map_path
        String out_cell_barcodes_file_path
        String out_file_likely_donors_path
        String out_pdf_path
        String out_tear_sheet_pdf_path

        # runtime values
        String docker = "quay.io/broadinstitute/drop-seq_r:current"
        Int cpu = 2
        Int memory_mb = 4096
        Int disk_gb = 10
        Int preemptible = 2
    }

    command <<<
        set -euo pipefail

        Rscript \
            -e 'message(date(), " Start ", "donorAssignmentQC")' \
            -e 'suppressPackageStartupMessages(library(DropSeq.dropulation))' \
            -e 'donorAssignmentQC(
                expName="~{exp_name}",
                likelihoodSummaryFile="~{likelihood_summary_file}",
                doubletLikelihoodFile="~{doublet_likelihood_file}",
                dgeSummaryFile="~{dge_summary_file}",
                dgeRawSummaryFile="~{dge_raw_summary_file}",
                dgeFile="~{dge_file}",
                readsPerCellFile="~{reads_per_cell_file}",
                ~{if defined(census_file) then "censusFile=\"" + census_file + "\"," else ""}
                outFileLikelyDonors="~{out_file_likely_donors_path}",
                outDonorToCellMap="~{out_donor_to_cell_map_path}",
                outPDF="~{out_pdf_path}",
                outSummaryStatsFile="~{out_summary_stats_file_path}",
                expectedSamplesFile="~{expected_samples_file}",
                outCellBarcodesFile="~{out_cell_barcodes_file_path}",
                outTearSheetPDF="~{out_tear_sheet_pdf_path}"
            )' \
            -e 'message(date(), " Done ", "donorAssignmentQC")'

        grep -avE '^/(Creation|Mod)Date' ~{out_pdf_path} > ~{out_pdf_path}.tmp
        mv ~{out_pdf_path}.tmp ~{out_pdf_path}
    >>>

    runtime {
        docker: docker
        cpu: cpu
        memory: memory_mb + " MB"
        disks: "local-disk " + disk_gb + " HDD"
        preemptible: preemptible
    }

    output {
        File out_summary_stats_file = out_summary_stats_file_path
        File out_donor_to_cell_map = out_donor_to_cell_map_path
        File out_cell_barcodes_file = out_cell_barcodes_file_path
        File out_file_likely_donors = out_file_likely_donors_path
        File out_pdf = out_pdf_path
        File out_tear_sheet_pdf = out_tear_sheet_pdf_path
    }
}
