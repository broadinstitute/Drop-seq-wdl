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

task plot_gene_qtls {
    input {
        # required inputs
        File cis_qtl
        File genotype_bed
        File gene_expression

        # required outputs
        String pdf_path

        # runtime values
        String docker = "quay.io/broadinstitute/drop-seq_r:current"
        Int cpu = 2
        Int memory_mb = 16384
        Int disk_gb = 10
        Int preemptible = 2
    }

    String genotype_matrix_path = basename(genotype_bed, ".bed.gz") + ".txt"

    # Convert the input files to the format expected by the DropSeq.eqtl::plotGeneQTLs function.
    # To avoid backticks in the R script we write a temp file and then rename the column headers.
    # Using only builtin R functions to avoid dependencies on additional packages.
    # Use grep -avE to strip out the internal modification time for reproducibility.
    command <<<
        set -euo pipefail

        cat >convert.R <<SCRIPT
        df <-
          read.table(
            gzfile("~{cis_qtl}"),
            header = TRUE,
            sep = "\t",
            stringsAsFactors = FALSE,
            colClasses = "character"
          )

        eqtl_results_df <- df[, c("phenotype_id", "variant_id", "pval_nominal", "qval")]
        colnames(eqtl_results_df) <- c("gene", "SNP", "pvalue", "qvalue")
        write.table(
          eqtl_results_df,
          "eqtl_results_tmp.txt",
          sep = "\t",
          row.names = FALSE,
          quote = FALSE
        )

        snps <- df[, "variant_id"] |> unique()
        split_snps <- do.call(rbind, strsplit(snps, ":", fixed = TRUE))
        variant_locations_df <-
          data.frame(
            chr = split_snps[, 1],
            pos = split_snps[, 2],
            snp = snps,
            stringsAsFactors = FALSE
          )
        write.table(
          variant_locations_df,
          "variant_locations.txt",
          sep = "\t",
          row.names = FALSE,
          quote = FALSE
        )
        SCRIPT

        Rscript convert.R

        zcat ~{genotype_bed} | cut -f 4- | sed '1 s/^pid/id/' > ~{genotype_matrix_path}
        zcat ~{gene_expression} | cut -f 4- | sed '1 s/^pid/id/' > gene_expression.txt
        sed '1 s/pvalue/p-value/' eqtl_results_tmp.txt > eqtl_results.txt

        Rscript \
            -e 'message(date(), " Start ", "plotGeneQTLs")' \
            -e 'suppressPackageStartupMessages(library(DropSeq.eqtl))' \
            -e 'plotGeneQTLs(
                eQTLPermutationResultFile="eqtl_results.txt",
                expression_file_name="gene_expression.txt",
                SNP_file_name="~{genotype_matrix_path}",
                snps_location_file_name="variant_locations.txt",
                outPDF="~{pdf_path}"
            )' \
            -e 'message(date(), " Done ", "plotGeneQTLs")'

        grep -avE '^/(Creation|Mod)Date' ~{pdf_path} > ~{pdf_path}.tmp
        mv ~{pdf_path}.tmp ~{pdf_path}
    >>>

    runtime {
        docker: docker
        cpu: cpu
        memory: memory_mb + " MB"
        disks: "local-disk " + disk_gb + " HDD"
        preemptible: preemptible
    }

    output {
        File pdf = pdf_path
    }
}
