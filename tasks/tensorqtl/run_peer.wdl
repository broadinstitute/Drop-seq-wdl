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

task run_peer {
    input {
        # required inputs
        File gene_expression
        Int extract_peer_factors
        File covariates

        # required outputs
        String gene_expression_peer_path
        String covariates_peer_path

        # optional inputs
        String run_peer_timeout = "3h"

        # runtime values
        String docker = "gcr.io/broad-cga-francois-gtex/gtex_eqtl:V9"
        Int cpu = 2
        Int memory_mb = 8192
        Int disk_gb = 10
        Int preemptible = 2
    }

    String temp_output_prefix = "temp_output"
    String peer_covariates_path = temp_output_prefix + ".PEER_covariates.txt"
    String peer_residuals_path = temp_output_prefix + ".PEER_residuals.txt"
    String covariates_transposed_path = temp_output_prefix + ".covariates_transposed.txt"

    # Skip running PEER if there are no covariates and no factors to extract.
    # sed in a replacement to run_PEER.R to use seq_len, just in case the number of peer factors is zero.
    # Uses timeout to make sure that run_PEER.R doesn't get stuck for hours running on bad input data.
    # If the timeout is reached will exit with timeout's default code 124.
    # Applying residuals adapted from 3rdParty/peer/src/PEER.R
    # Use gzip -n to strip out the internal modification time for reproducibility.
    # If upgrading the docker, check if we no longer need to set alphaprior_b below:
    # https://github.com/broadinstitute/gtex-pipeline/issues/80
    command <<<
        set -euo pipefail
        set -x

        count_covariates=$(tail -n +2 ~{covariates} | wc -l)
        if ((~{extract_peer_factors} == 0)) && ((count_covariates == 0)); then
            cp ~{gene_expression} ~{gene_expression_peer_path}
            cp ~{covariates} ~{covariates_peer_path}
            exit 0
        fi

        python3 -c "
        import pandas as pd
        pd.read_csv(
           '~{covariates}',
            sep='\t',
            dtype=str,
            index_col=0,
        ).T.to_csv(
            '~{covariates_transposed_path}',
            sep='\t',
            index=True,
        )
        "

        sed -E \
            's/paste0\("InferredCov",1:\(ncol\(X\)-dim\(covar.df\)\[2\]\)\)/sapply(seq_len(ncol(X)-dim(covar.df)[2]),function(x){paste0("InferredCov",x)})/' \
            /src/run_PEER.R \
        > run_PEER_patched.R

        timeout ~{run_peer_timeout} \
        Rscript --vanilla \
            run_PEER_patched.R \
            --alphaprior_b 0.1 \
            ~{gene_expression} \
            ~{temp_output_prefix} \
            ~{extract_peer_factors} \
            --covariates ~{covariates_transposed_path}

        cat >expression_peer.R <<SCRIPT
        expr_df <- read.table('~{gene_expression}', sep = '\t', header = T, check.names = F, comment.char = '')
        residuals_df <- read.table('~{peer_residuals_path}', sep = '\t', header = T, check.names = F, comment.char = '')
        M <- as.matrix(expr_df[, 5:ncol(expr_df)])
        R <- as.matrix(residuals_df[, 2:ncol(residuals_df)])
        expr_peer_m <- R + apply(M, 1, mean)
        expr_peer_df <- data.frame(cbind(expr_df[, 1:4], expr_peer_m), stringsAsFactors = F, check.names = F)
        write.table(expr_peer_df, gzfile('~{gene_expression_peer_path}'), sep = '\t', col.names = T, row.names = F, quote = F)
        SCRIPT

        Rscript --vanilla expression_peer.R

        re_gz() {
            local gz_file=$1
            local tmp_file=$gz_file.tmp
            if [[ $gz_file != *.gz ]]; then return; fi
            mv "$gz_file" "$tmp_file"
            gunzip -c "$tmp_file" | gzip -n > "$gz_file"
        }

        re_gz ~{gene_expression_peer_path}
        mv ~{peer_covariates_path} ~{covariates_peer_path}
    >>>

    runtime {
        docker: docker
        cpu: cpu
        memory: memory_mb + " MB"
        disks: "local-disk " + disk_gb + " HDD"
        preemptible: preemptible
    }

    output {
        File gene_expression_peer = gene_expression_peer_path
        File covariates_peer = covariates_peer_path
    }
}
