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

import "compute_drop_seq_alignment_metrics.wdl"
import "../../tasks/common/merge_metrics.wdl"
import "../../tasks/optimus_post_processing/add_or_replace_read_groups.wdl"
import "../../tasks/optimus_post_processing/apply_bqsr.wdl"
import "../../tasks/optimus_post_processing/base_recalibrator.wdl"
import "../../tasks/optimus_post_processing/gather_bqsr_reports.wdl"
import "../../tasks/optimus_post_processing/mark_chimeric_reads.wdl"
import "../../tasks/optimus_post_processing/optimus_h5ad_to_dropseq.wdl"
import "../../tasks/optimus_post_processing/plot_alignment_metrics.wdl"
import "../../tasks/optimus_post_processing/plot_locus_function_metrics.wdl"
import "../../tasks/optimus_post_processing/set_nm_md_and_uq_tags.wdl"
import "../../tasks/optimus_post_processing/single_cell_rna_seq_metrics_collector.wdl"
import "../../tasks/optimus_post_processing/split_bam_by_cell.wdl"
import "../../tasks/optimus_post_processing/tag_read_with_gene_function.wdl"
import "../../tasks/optimus_post_processing/transform_dge.wdl"
import "../../tasks/optimus_post_processing/validate_sam_file.wdl"

workflow optimus_post_processing {
    input {
        # required inputs
        String library_name # v123_10X-GEX-3P_abc_rxn8
        File optimus_bam
        File optimus_h5ad
        File fasta
        File fasta_idx
        File fasta_dict
        File gtf
        File ref_flat
        Int estimated_num_cells

        # optional inputs
        File? ribosomal_intervals
        File? dbsnp_vcf
        File? dbsnp_vcf_idx
        File? dbsnp_intervals
        Int? min_transcripts
        Int split_bam_size_gb = 2
        String? cell_barcode_tag # CB
        String? molecular_barcode_tag # UB
        String? chimeric_molecular_barcode_tag # UR
        String? read_group_platform # Illumina
        String? read_group_platform_unit # 12FLCELL3.ACTGACTGAC.ATCGATCGAT.1
        String? read_group_sequencing_center # BI
        Boolean add_read_group =
            defined(read_group_platform) && defined(read_group_platform_unit) && defined(read_group_sequencing_center)
        Boolean do_bqsr = defined(dbsnp_vcf) && defined(dbsnp_vcf_idx)
        Array[String] locus_function_list = [] # ["INTRONIC"]
        Array[String] mt_sequences = [] # ["chrM"]
        String? strand_strategy # SENSE
    }

    call optimus_h5ad_to_dropseq.optimus_h5ad_to_dropseq as optimus_h5ad_to_dropseq {
        input:
            input_h5ad = optimus_h5ad,
            min_transcripts = min_transcripts,
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
            output_bams_pattern = library_name + ".__SPLITNUM__.bam",
            output_manifest_path = library_name + ".split_bam_manifest.gz",
            # This job takes a long time to run, and seems to preempt often enough to exhaust the premption count anyway
            preemptible = 0
    }

    Array[File] split_by_cell_bams = split_bam_by_cell.output_bams

    scatter (split_by_cell_bam_num in range(length(split_by_cell_bams))) {
        call single_cell_rna_seq_metrics_collector.single_cell_rna_seq_metrics_collector as single_cell_rna_seq_metrics_collector {
            input:
                input_bam = split_by_cell_bams[split_by_cell_bam_num],
                annotations_file = gtf,
                ribosomal_intervals = ribosomal_intervals,
                cell_bc_file = select_first([optimus_h5ad_to_dropseq.output_barcodes]),
                cell_barcode_tag = cell_barcode_tag,
                mt_sequences = mt_sequences,
                output_metrics_path = library_name + "." + split_by_cell_bam_num + ".fracIntronicExonicPerCell.txt.gz"
        }

        if (add_read_group) {
            call add_or_replace_read_groups.add_or_replace_read_groups as add_or_replace_read_groups {
                input:
                    input_bam = split_by_cell_bams[split_by_cell_bam_num],
                    platform = read_group_platform,
                    library = library_name,
                    sample_name = library_name,
                    platform = select_first([read_group_platform]),
                    platform_unit = select_first([read_group_platform_unit]),
                    sequencing_center = read_group_sequencing_center,
                    output_bam_path = library_name + "." + split_by_cell_bam_num + ".rg.bam"
            }
        }

        call set_nm_md_and_uq_tags.set_nm_md_and_uq_tags as set_nm_md_and_uq_tags {
            input:
                input_bam = select_first([
                    add_or_replace_read_groups.output_bam,
                    split_by_cell_bams[split_by_cell_bam_num]
                ]),
                fasta = fasta,
                output_bam_path = library_name + "." + split_by_cell_bam_num + ".nm_md_uq_tagged.bam"
        }

        call tag_read_with_gene_function.tag_read_with_gene_function as tag_read_with_gene_function {
            input:
                input_bam = set_nm_md_and_uq_tags.output_bam,
                gtf = gtf,
                output_bam_path = library_name + "." + split_by_cell_bam_num + ".gf_tagged.bam"
        }

        call mark_chimeric_reads.mark_chimeric_reads as mark_chimeric_reads {
            input:
                bam = tag_read_with_gene_function.output_bam,
                cell_barcode_tag = cell_barcode_tag,
                molecular_barcode_tag = chimeric_molecular_barcode_tag,
                cell_bc_file = select_first([optimus_h5ad_to_dropseq.output_barcodes]),
                locus_function_list = locus_function_list,
                strand_strategy = strand_strategy,
                output_bam_path =
                    library_name + "." + split_by_cell_bam_num + if do_bqsr then ".chimeric_marked.bam" else ".bam",
                output_report_path = library_name + "." + split_by_cell_bam_num + ".chimeric_transcripts.txt.gz",
                output_metrics_path = library_name + "." + split_by_cell_bam_num + ".chimeric_read_metrics"
        }

        if (do_bqsr) {
            call base_recalibrator.base_recalibrator as base_recalibrator {
                input:
                    input_bams = select_all([mark_chimeric_reads.output_bam]),
                    fasta = fasta,
                    fasta_idx = fasta_idx,
                    fasta_dict = fasta_dict,
                    known_sites_vcfs = select_all([dbsnp_vcf]),
                    known_sites_vcf_idxs = select_all([dbsnp_vcf_idx]),
                    intervals = dbsnp_intervals,
                    output_file_path = library_name + "." + split_by_cell_bam_num + ".bqsr.recal.txt"
            }
        }
    }

    Array[File] chimeric_marked_bams = select_all(mark_chimeric_reads.output_bam)

    if (do_bqsr) {
        call gather_bqsr_reports.gather_bqsr_reports as gather_bqsr_reports {
            input:
                input_files = select_all(base_recalibrator.output_file),
                output_file_path = library_name + ".bqsr.recal.txt"
        }

        scatter (chimeric_marked_bam_num in range(length(chimeric_marked_bams))) {
            call apply_bqsr.apply_bqsr as apply_bqsr {
                input:
                    input_bam = chimeric_marked_bams[chimeric_marked_bam_num],
                    fasta = fasta,
                    fasta_idx = fasta_idx,
                    fasta_dict = fasta_dict,
                    bqsr_recal_file = gather_bqsr_reports.output_file,
                    disable_read_filter = ["WellformedReadFilter"],
                    output_bam_path = library_name + "." + chimeric_marked_bam_num + ".bam"
            }
        }
    }

    Array[File] output_bams = if (do_bqsr) then select_first([apply_bqsr.output_bam]) else chimeric_marked_bams

    scatter (output_bam_num in range(length(output_bams))) {
        call validate_sam_file.validate_sam_file as validate_sam_file {
            input:
                input_bam = output_bams[output_bam_num],
                fasta = fasta,
                fasta_idx = fasta_idx,
                fasta_dict = fasta_dict
        }
    }

    call compute_drop_seq_alignment_metrics.compute_drop_seq_alignment_metrics as compute_drop_seq_alignment_metrics {
        input:
            library_name = library_name,
            input_bams = output_bams,
            ref_flat = ref_flat,
            ribosomal_intervals = ribosomal_intervals,
            cell_barcode_tag = cell_barcode_tag,
            molecular_barcode_tag = molecular_barcode_tag
    }

    File alignment_quality_file = select_first([
        compute_drop_seq_alignment_metrics.read_quality_metrics,
        optimus_h5ad_to_dropseq.output_read_quality_metrics
    ])

    call merge_metrics.merge_metrics as merge_single_cell_rna_seq_metrics {
        input:
            merge_program = "MergeSingleCellRnaSeqMetrics",
            input_files = select_all(single_cell_rna_seq_metrics_collector.output_metrics),
            output_file_path = library_name + ".fracIntronicExonicPerCell.txt.gz",
    }

    call merge_metrics.merge_metrics as merge_molecular_barcode_distribution_by_gene {
        input:
            merge_program = "MergeMolecularBarcodeDistributionByGene",
            other_args = "--COLUMN_FLEXIBILTY true",
            input_files = select_all(mark_chimeric_reads.output_report),
            output_file_path = library_name + ".chimeric_transcripts.txt.gz",
            docker = "us.gcr.io/mccarroll-scrna-seq/drop-seq_private_java:current"
    }

    call merge_metrics.merge_metrics as merge_chimeric_read_metrics {
        input:
            merge_program = "MergeChimericReadMetrics",
            other_args = "--DELETE_INPUTS false",
            input_files = select_all(mark_chimeric_reads.output_metrics),
            output_file_path = library_name + ".chimeric_read_metrics"
    }

    call plot_locus_function_metrics.plot_locus_function_metrics as plot_locus_function_metrics {
        input:
            digital_expression_summary_file = select_first([optimus_h5ad_to_dropseq.output_digital_expression_summary]),
            exon_intron_per_cell_file = merge_single_cell_rna_seq_metrics.output_file,
            cell_bc_counts_file = compute_drop_seq_alignment_metrics.num_reads_per_cell_barcode,
            estimated_num_cells = estimated_num_cells,
            out_plot_path = library_name + ".locusFunction.pdf"
    }

    call plot_alignment_metrics.plot_alignment_metrics as plot_alignment_metrics {
        input:
            alignment_quality_file = alignment_quality_file,
            mean_quality_all_file = compute_drop_seq_alignment_metrics.mean_quality_by_cycle_all_metrics,
            mean_quality_aligned_file = compute_drop_seq_alignment_metrics.mean_quality_by_cycle_aligned_metrics,
            exon_intron_file = compute_drop_seq_alignment_metrics.rna_seq_metrics,
            cell_bc_counts_file = compute_drop_seq_alignment_metrics.num_reads_per_cell_barcode,
            alignment_quality_by_cell_file = compute_drop_seq_alignment_metrics.read_quality_by_cell_metrics,
            base_pct_matrix_molecular_file =
                compute_drop_seq_alignment_metrics.base_distribution_at_read_position_molecular,
            base_pct_matrix_cell_file = compute_drop_seq_alignment_metrics.base_distribution_at_read_position_cellular,
            exon_intron_per_cell_file = merge_single_cell_rna_seq_metrics.output_file,
            selected_cells_file = optimus_h5ad_to_dropseq.output_barcodes,
            estimated_num_cells = estimated_num_cells,
            out_plot_path = library_name + ".alignment.pdf"
    }

    output {
        File dropseq_h5ad = select_first([optimus_h5ad_to_dropseq.output_h5ad])
        Array[File] dropseq_bam = if select_first(validate_sam_file.done) then output_bams else output_bams
        File dropseq_bam_manifest = select_first([split_bam_by_cell.output_manifest])
        File digital_expression = transform_dge.output_file
        File digital_expression_summary = select_first([optimus_h5ad_to_dropseq.output_digital_expression_summary])
        File mtx = select_first([optimus_h5ad_to_dropseq.output_mtx])
        File barcodes = select_first([optimus_h5ad_to_dropseq.output_barcodes])
        File features = select_first([optimus_h5ad_to_dropseq.output_features])
        File reads_per_cell = select_first([optimus_h5ad_to_dropseq.output_reads_per_cell_file])
        File read_quality_metrics = alignment_quality_file
        File cell_selection_report = select_first([optimus_h5ad_to_dropseq.output_cell_selection_report])
        File chimeric_transcripts = merge_molecular_barcode_distribution_by_gene.output_file
        File chimeric_read_metrics = merge_chimeric_read_metrics.output_file
        File rna_seq_metrics = compute_drop_seq_alignment_metrics.rna_seq_metrics
        File read_quality_by_cell_metrics = compute_drop_seq_alignment_metrics.read_quality_by_cell_metrics
        File mean_quality_by_cycle_all_metrics = compute_drop_seq_alignment_metrics.mean_quality_by_cycle_all_metrics
        File mean_quality_by_cycle_all_chart = compute_drop_seq_alignment_metrics.mean_quality_by_cycle_all_chart
        File mean_quality_by_cycle_aligned_metrics =
            compute_drop_seq_alignment_metrics.mean_quality_by_cycle_aligned_metrics
        File mean_quality_by_cycle_aligned_chart =
            compute_drop_seq_alignment_metrics.mean_quality_by_cycle_aligned_chart
        File num_reads_per_cell_barcode = compute_drop_seq_alignment_metrics.num_reads_per_cell_barcode
        File base_distribution_at_read_position_cellular_metrics =
            compute_drop_seq_alignment_metrics.base_distribution_at_read_position_cellular
        File base_distribution_at_read_position_molecular_metrics =
            compute_drop_seq_alignment_metrics.base_distribution_at_read_position_molecular
        File locus_function_pdf = plot_locus_function_metrics.out_plot
        File alignment_pdf = plot_alignment_metrics.out_plot
    }
}
