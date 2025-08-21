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

import "../../tasks/tensorqtl/annotate_qtls.wdl"
import "../../tasks/tensorqtl/concat_files.wdl"
import "../../tasks/tensorqtl/lookup_contig_groups.wdl"
import "../../tasks/tensorqtl/make_intervals.wdl"
import "../../tasks/tensorqtl/merge_parquet_files.wdl"
import "../../tasks/tensorqtl/normalize_tensorqtl_expression.wdl"
import "../../tasks/tensorqtl/pairs_to_vcf.wdl"
import "../../tasks/tensorqtl/plot_diversity.wdl"
import "../../tasks/tensorqtl/plot_gene_qtls.wdl"
import "../../tasks/tensorqtl/prepare_eqtl_data.wdl"
import "../../tasks/tensorqtl/prepare_eqtl_genotype_data.wdl"
import "../../tasks/tensorqtl/prepare_tensorqtl_data.wdl"
import "../../tasks/tensorqtl/run_peer.wdl"
import "../../tasks/tensorqtl/sign_test_qtl.wdl"
import "../../tasks/tensorqtl/tensorqtl_independent.wdl"
import "../../tasks/tensorqtl/tensorqtl_nominal.wdl"
import "../../tasks/tensorqtl/tensorqtl_permutations.wdl"

workflow tensorqtl {
    input {
        # required inputs
        File metacells
        File annotations
        File sequence_dictionary
        File contig_groups_yaml
        File dbsnp_vcf
        File vcf
        File vcf_idx
        File donor_covariates

        # required outputs
        String output_prefix

        # optional inputs
        File? rejected_donor_list
        Array[String] ignore_contig_groups = [ "Y", "MT" ]
        Int gq_threshold = 30
        Float remove_pct_expression = 50
        Float fraction_samples_passing = 0.9
        Float hwe_pvalue = 0.0001
        Float maf_threshold = 0.05
        Array[String] prepare_eqtl_data_args = []
        Int extract_peer_factors = 0
        Int cis_window_size = 1000000
        Array[File] sign_test_unfiltered_qtls = []
        Float sign_test_qvalue_threshold = 0.05
    }

    call plot_diversity.plot_diversity as plot_diversity {
        input:
            metacells = metacells,
            pdf_path = output_prefix + ".diversity.pdf"
    }

    call lookup_contig_groups.lookup_contig_groups as lookup_ignored_chromosomes {
        input:
            contig_groups_yaml = contig_groups_yaml,
            contig_groups = ignore_contig_groups
    }

    if (length(prepare_eqtl_data_args) > 0) {
        call prepare_eqtl_data.prepare_eqtl_data as prepare_eqtl_data_serial {
            input:
                metacells = metacells,
                donor_covariates = donor_covariates,
                vcf = vcf,
                vcf_idx = vcf_idx,
                annotations = annotations,
                sequence_dictionary = sequence_dictionary,
                remove_pct_expression = remove_pct_expression,
                gq_threshold = gq_threshold,
                fraction_samples_passing = fraction_samples_passing,
                hwe_pvalue = hwe_pvalue,
                maf = maf_threshold,
                ignored_chromosomes = lookup_ignored_chromosomes.contigs,
                rejected_donor_list = rejected_donor_list,
                prepare_eqtl_data_args = prepare_eqtl_data_args,
                genotype_bed_path = output_prefix + ".genotype_matrix.bed.gz",
                gene_expression_path = output_prefix + ".gene_expression.bed.gz",
                covariates_path = output_prefix + ".covariates.txt"
        }
    }

    if (length(prepare_eqtl_data_args) == 0) {
        call make_intervals.make_intervals as make_intervals {
            input:
                sequence_dictionary = sequence_dictionary,
                contig_groups_yaml = contig_groups_yaml,
                ignore_contig_groups = ignore_contig_groups,
                output_prefix = output_prefix
        }

        call prepare_eqtl_data.prepare_eqtl_data as prepare_eqtl_data_parallel {
            input:
                metacells = metacells,
                donor_covariates = donor_covariates,
                vcf = vcf,
                vcf_idx = vcf_idx,
                annotations = annotations,
                sequence_dictionary = sequence_dictionary,
                remove_pct_expression = remove_pct_expression,
                gq_threshold = gq_threshold,
                fraction_samples_passing = fraction_samples_passing,
                hwe_pvalue = hwe_pvalue,
                maf = maf_threshold,
                ignored_chromosomes = lookup_ignored_chromosomes.contigs,
                rejected_donor_list = rejected_donor_list,
                prepare_eqtl_data_args = prepare_eqtl_data_args,
                interval_file = sequence_dictionary, # use the sequence dictionary to produce an empty genotypes here.
                genotype_bed_path = output_prefix + ".genotype_matrix.empty.bed.gz",
                gene_expression_path = output_prefix + ".gene_expression.bed.gz",
                covariates_path = output_prefix + ".covariates.txt",
                donor_list_path = output_prefix + ".donors.txt"
        }

        scatter(interval_file in make_intervals.interval_files) {
            call prepare_eqtl_genotype_data.prepare_eqtl_genotype_data as prepare_eqtl_genotype_data {
                input:
                    vcf = vcf,
                    vcf_idx = vcf_idx,
                    interval_file = interval_file,
                    donor_list = select_first([prepare_eqtl_data_parallel.donor_list]),
                    gq_threshold = gq_threshold,
                    fraction_samples_passing = fraction_samples_passing,
                    hwe_pvalue = hwe_pvalue,
                    maf = maf_threshold,
                    ignored_chromosomes = lookup_ignored_chromosomes.contigs,
                    genotype_bed_path = output_prefix + ".genotype_matrix.bed.gz"
            }
        }

        call concat_files.concat_files as concat_genotype_bed {
            input:
                files = prepare_eqtl_genotype_data.genotype_bed,
                header_count = 1,
                out_path = output_prefix + ".genotype_matrix.bed.gz"
        }
    }

    File prepare_eqtl_data_genotype_bed = select_first([prepare_eqtl_data_serial.genotype_bed, concat_genotype_bed.out])
    File prepare_eqtl_data_gene_expression = select_first([prepare_eqtl_data_serial.gene_expression, prepare_eqtl_data_parallel.gene_expression])
    File prepare_eqtl_data_covariates = select_first([prepare_eqtl_data_serial.covariates, prepare_eqtl_data_parallel.covariates])

    call normalize_tensorqtl_expression.normalize_tensorqtl_expression as normalize_tensorqtl_expression {
        input:
            gene_expression = prepare_eqtl_data_gene_expression,
            gene_expression_tpm_path = output_prefix + ".gene_expression_tpm.bed.gz",
            gene_expression_int_path = output_prefix + ".gene_expression_normalized.bed.gz"
    }

    File gene_expression_tpm_bed = select_first([normalize_tensorqtl_expression.gene_expression_tpm])
    File gene_expression_int_bed = select_first([normalize_tensorqtl_expression.gene_expression_int])

    call run_peer.run_peer as run_peer {
        input:
            gene_expression = gene_expression_int_bed,
            covariates = prepare_eqtl_data_covariates,
            extract_peer_factors = extract_peer_factors,
            gene_expression_peer_path = output_prefix + ".gene_expression_normalized_peer.bed.gz",
            covariates_peer_path = output_prefix + ".covariates_peer.txt"
    }

    call prepare_tensorqtl_data.prepare_tensorqtl_data as prepare_tensorqtl_data {
        input:
            genotype_bed = prepare_eqtl_data_genotype_bed,
            gene_expression = gene_expression_int_bed,
            covariates = run_peer.covariates_peer,
            genotype_matrix_tensorqtl_path = output_prefix + ".genotype_matrix_tensorqtl.bed.parquet",
            gene_expression_tensorqtl_path = output_prefix + ".gene_expression_tensorqtl.bed.parquet",
            covariates_tensorqtl_path = output_prefix + ".covariates_tensorqtl.txt"
    }

    call tensorqtl_permutations.tensorqtl_permutations as tensorqtl_permutations {
        input:
            genotype_matrix = prepare_tensorqtl_data.genotype_matrix_tensorqtl,
            gene_expression = prepare_tensorqtl_data.gene_expression_tensorqtl,
            covariates = prepare_tensorqtl_data.covariates_tensorqtl,
            cis_window_size = cis_window_size,
            maf_threshold = maf_threshold,
            output_prefix = output_prefix
    }

    call tensorqtl_independent.tensorqtl_independent as tensorqtl_independent {
        input:
            genotype_matrix = prepare_tensorqtl_data.genotype_matrix_tensorqtl,
            gene_expression = prepare_tensorqtl_data.gene_expression_tensorqtl,
            covariates = prepare_tensorqtl_data.covariates_tensorqtl,
            cis_window_size = cis_window_size,
            maf_threshold = maf_threshold,
            cis_qtl = tensorqtl_permutations.cis_qtl,
            output_prefix = output_prefix
    }

    call tensorqtl_nominal.tensorqtl_nominal as tensorqtl_nominal {
        input:
            genotype_matrix = prepare_tensorqtl_data.genotype_matrix_tensorqtl,
            gene_expression = prepare_tensorqtl_data.gene_expression_tensorqtl,
            covariates = prepare_tensorqtl_data.covariates_tensorqtl,
            cis_window_size = cis_window_size,
            maf_threshold = maf_threshold,
            output_prefix = output_prefix
    }

    call merge_parquet_files.merge_parquet_files as merge_parquet_files {
        input:
            input_files = tensorqtl_nominal.cis_qtl_pairs,
            out_path = output_prefix + ".cis_qtl_pairs.txt.gz"
    }

    call pairs_to_vcf.pairs_to_vcf as pairs_to_vcf {
        input:
            variant_gene_pairs = merge_parquet_files.out,
            vcf = vcf,
            vcf_idx = vcf_idx,
            variant_column = "variant_id",
            out_path = output_prefix + ".cis_qtl_pairs.vcf.gz"
    }

    call plot_gene_qtls.plot_gene_qtls as plot_gene_qtls {
        input:
            cis_qtl = tensorqtl_permutations.cis_qtl,
            genotype_bed = prepare_eqtl_data_genotype_bed,
            gene_expression = run_peer.gene_expression_peer,
            pdf_path = output_prefix + ".cis_qtl.pdf"
    }

    call plot_gene_qtls.plot_gene_qtls as plot_gene_qtls_tpm {
        input:
            cis_qtl = tensorqtl_permutations.cis_qtl,
            genotype_bed = prepare_eqtl_data_genotype_bed,
            gene_expression = select_first([normalize_tensorqtl_expression.gene_expression_tpm]),
            pdf_path = output_prefix + ".cis_qtl_tpm.pdf"
    }

    scatter(sign_test_unfiltered_qtl in sign_test_unfiltered_qtls) {
        # Remove common suffixes to produce a base name for the unfiltered qtl file.
        String sign_test_unfiltered_qtl_base =
            basename(basename(
                basename(basename(
                        basename(sign_test_unfiltered_qtl, ".gz"),
                    ".txt"), ".tsv"),
            ".allpairs"), "_all_results.GRCH38")

        call sign_test_qtl.sign_test_qtl as sign_test_qtl {
            input:
                cis_qtl = tensorqtl_permutations.cis_qtl,
                unfiltered_qtl = sign_test_unfiltered_qtl,
                qvalue_threshold = sign_test_qvalue_threshold,
                sign_test_path = sign_test_unfiltered_qtl_base + "." + output_prefix + ".sign_test.txt"
        }
    }

    call annotate_qtls.annotate_qtls as annotate_qtls {
        input:
            qtl = tensorqtl_permutations.cis_qtl,
            dbsnp_vcf = dbsnp_vcf,
            annotations = annotations,
            annotated_qtl_path = output_prefix + ".cis_qtl_ann.txt.gz"
    }

    output {
        File diversity_pdf = plot_diversity.pdf
        File genotype_bed = prepare_eqtl_data_genotype_bed
        File gene_expression = prepare_eqtl_data_gene_expression
        File gene_expression_tpm = gene_expression_tpm_bed
        File gene_expression_int = gene_expression_int_bed
        File gene_expression_peer = run_peer.gene_expression_peer
        File covariates = prepare_eqtl_data_covariates
        File covariates_peer = run_peer.covariates_peer
        File cis_qtl = tensorqtl_permutations.cis_qtl
        File cis_qtl_pdf = plot_gene_qtls.pdf
        File cis_qtl_tpm_pdf = plot_gene_qtls_tpm.pdf
        File cis_independent_qtl = tensorqtl_independent.cis_independent_qtl
        File cis_qtl_pairs = merge_parquet_files.out
        File cis_qtl_pairs_zip = tensorqtl_nominal.cis_qtl_pairs_zip
        File cis_qtl_pairs_vcf = pairs_to_vcf.out
        File cis_qtl_pairs_vcf_idx = pairs_to_vcf.out_idx
        Array[File] sign_tests = sign_test_qtl.sign_test
        File annotated_qtl = annotate_qtls.annotated_qtl
    }
}
