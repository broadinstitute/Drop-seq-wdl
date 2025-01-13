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

import "../../tasks/common/merge_metrics.wdl"
import "../../tasks/optimus_post_processing/mark_chimeric_reads.wdl"
import "../../tasks/optimus_post_processing/optimus_h5ad_to_dropseq.wdl"
import "../../tasks/optimus_post_processing/split_bam_by_cell.wdl"
import "../../tasks/optimus_post_processing/tag_read_with_gene_function.wdl"
import "../../tasks/optimus_post_processing/transform_dge.wdl"

workflow optimus_post_processing {
    input {
        # required inputs
        String library_name # v123_10X-GEX-3P_abc_rxn8
        File optimus_bam
        File optimus_h5ad
        File gtf

        # optional inputs
        Int num_transcripts_threshold = 20
        Int split_bam_size_gb = 2
        String? cell_barcode_tag # CB
        String? chimeric_molecular_barcode_tag # UR
        Array[String] locus_function_list = [] # ["INTRONIC"]
    }

    call optimus_h5ad_to_dropseq.optimus_h5ad_to_dropseq as optimus_h5ad_to_dropseq {
        input:
            input_h5ad = optimus_h5ad,
            num_transcripts_threshold = num_transcripts_threshold,
            output_h5ad_path = library_name + ".dropulation.h5ad",
            output_mtx_path = "matrix.mtx.gz",
            output_barcodes_path = "barcodes.tsv.gz",
            output_features_path = "features.tsv.gz",
            output_digital_expression_summary_path = library_name + ".digital_expression_summary.txt",
            output_reads_per_cell_file_path = library_name + ".reads_per_cell.txt.gz",
            output_read_quality_metrics_path = library_name + ".ReadQualityMetrics.txt",
            output_cell_selection_report_path = library_name + ".cell_selection_report.txt"
    }

    call transform_dge.transform_dge as transform_dge {
        input:
            input_file = select_first([optimus_h5ad_to_dropseq.output_mtx]),
            cell_file = optimus_h5ad_to_dropseq.output_barcodes,
            gene_file = optimus_h5ad_to_dropseq.output_features,
            order = ["null"],
            format_as_integer = true,
            output_file_path = library_name + ".digital_expression.txt.gz"
    }

    call split_bam_by_cell.split_bam_by_cell as split_bam_by_cell {
        input:
            input_bam = optimus_bam,
            split_tag = select_first([cell_barcode_tag, "CB"]),
            target_bam_size_gb = split_bam_size_gb,
            output_bams_pattern = library_name + ".__SPLITNUM__.untagged.bam",
            output_manifest_path = library_name + ".split_bam_manifest.gz",
            # This job takes a long time to run, and seems to preempt often enough to exhaust the premption count anyway
            preemptible = 0
    }

    scatter (idx in range(length(split_bam_by_cell.output_bams))) {
        call tag_read_with_gene_function.tag_read_with_gene_function as tag_read_with_gene_function {
            input:
                input_bam = split_bam_by_cell.output_bams[idx],
                gtf = gtf,
                output_bam_path = library_name + "." + idx + ".bam"
        }

        call mark_chimeric_reads.mark_chimeric_reads as mark_chimeric_reads {
            input:
                bam = tag_read_with_gene_function.output_bam,
                cell_barcode_tag = cell_barcode_tag,
                molecular_barcode_tag = chimeric_molecular_barcode_tag,
                cell_bc_file = select_first([optimus_h5ad_to_dropseq.output_barcodes]),
                locus_function_list = locus_function_list,
                output_report_path = library_name + "." + idx + ".chimeric_transcripts.txt.gz",
                output_metrics_path = library_name + "." + idx + ".chimeric_read_metrics"
        }
    }

    call merge_metrics.merge_metrics as merge_molecular_barcode_distribution_by_gene {
        input:
            merge_program = "MergeMolecularBarcodeDistributionByGene",
            other_args = "--COLUMN_FLEXIBILTY true",
            input_files = mark_chimeric_reads.output_report,
            output_file_path = library_name + ".chimeric_transcripts.txt.gz"
    }

    call merge_metrics.merge_metrics as merge_chimeric_read_metrics {
        input:
            merge_program = "MergeChimericReadMetrics",
            other_args = "--DELETE_INPUTS false",
            input_files = mark_chimeric_reads.output_metrics,
            output_file_path = library_name + ".chimeric_read_metrics"
    }

    output {
        File dropseq_h5ad = select_first([optimus_h5ad_to_dropseq.output_h5ad])
        Array[File] dropseq_bam = tag_read_with_gene_function.output_bam
        File dropseq_bam_manifest = select_first([split_bam_by_cell.output_manifest])
        File digital_expression = transform_dge.output_file
        File digital_expression_summary = select_first([optimus_h5ad_to_dropseq.output_digital_expression_summary])
        File mtx = select_first([optimus_h5ad_to_dropseq.output_mtx])
        File barcodes = select_first([optimus_h5ad_to_dropseq.output_barcodes])
        File features = select_first([optimus_h5ad_to_dropseq.output_features])
        File reads_per_cell = select_first([optimus_h5ad_to_dropseq.output_reads_per_cell_file])
        File read_quality_metrics = select_first([optimus_h5ad_to_dropseq.output_read_quality_metrics])
        File cell_selection_report = select_first([optimus_h5ad_to_dropseq.output_cell_selection_report])
        File chimeric_transcripts = merge_molecular_barcode_distribution_by_gene.output_file
        File chimeric_read_metrics = merge_chimeric_read_metrics.output_file
    }
}
