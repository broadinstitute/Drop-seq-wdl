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

task optimus_h5ad_to_dropseq {
    input {
        # required inputs
        File input_h5ad

        # optional inputs
        Int num_transcripts_threshold = 20

        # optional outputs
        String? output_h5ad_path
        String? output_mtx_path
        String? output_barcodes_path
        String? output_features_path
        String? output_digital_expression_path
        String? output_digital_expression_summary_path
        String? output_reads_per_cell_file_path
        String? output_read_quality_metrics_path
        String? output_cell_selection_report_path

        # runtime values
        String docker = "us.gcr.io/broad-gotc-prod/warp-tools:2.2.0"
        Int cpu = 2
        Int memory_mb = 8192
        Int disk_gb = 10 + if defined(output_mtx_path) then ceil(50 * size(input_h5ad, "GB")) else 0
        Int preemptible = 2
    }

    String output_digital_expression_txt =
        if defined(output_digital_expression_path) then
            basename(select_first([output_digital_expression_path]), ".gz")
        else
            "/dev/null"
    String output_reads_per_cell_file_txt =
        if defined(output_reads_per_cell_file_path) then
            basename(select_first([output_reads_per_cell_file_path]), ".gz")
        else
            "/dev/null"
    String output_mtx_txt =
        if defined(output_mtx_path) then
            basename(select_first([output_mtx_path]), ".gz")
        else
            "/dev/null"
    String output_barcodes_txt =
        if defined(output_barcodes_path) then
            basename(select_first([output_barcodes_path]), ".gz")
        else
            "/dev/null"
    String output_features_txt =
        if defined(output_features_path) then
            basename(select_first([output_features_path]), ".gz")
        else
            "/dev/null"

    command <<<
        set -euo pipefail

        python3 <<EOF
        import sys
        import anndata as ad
        import pandas as pd
        import numpy as np
        from scipy.io import mmwrite

        print('loading full adata', file=sys.stderr)
        adata = ad.read_h5ad('~{input_h5ad}')

        duplicated_gene_name = adata.var['gene_names'].duplicated(keep=False)
        num_duplicated_genes = duplicated_gene_name.sum()
        if num_duplicated_genes > 0:
            print(f'Removing {num_duplicated_genes} duplicated gene names', file=sys.stderr)
            adata = adata[:, ~duplicated_gene_name]

        # Convert the counts matrix to integers, and transpose where rows are genes and columns are cell barcodes
        matrix = adata.X.astype(int).T
        # Count the number of transcripts per cell barcode
        num_transcripts = matrix.sum(axis=0).A1

        num_transcripts_threshold = ~{num_transcripts_threshold}
        print(f'subsetting to barcodes with at least {num_transcripts_threshold} transcripts', file=sys.stderr)
        adata = adata[num_transcripts >= num_transcripts_threshold, :]

        # Convert the counts matrix to integers, and transpose where rows are genes and columns are cell barcodes
        matrix = adata.X.astype(int).T
        # Count the number of transcripts per cell barcode
        num_transcripts = matrix.sum(axis=0).A1

        # add additional columns with names that are expected by the downstream tools
        obs = adata.obs.copy()
        total_reads = obs['n_reads']
        mapped_reads = obs['reads_mapped_uniquely']
        obs['NUM_GENES'] = obs['n_genes']
        obs['NUM_GENIC_READS'] = obs['reads_mapped_exonic'] + obs['reads_mapped_exonic_as'] + \
                                 obs['reads_mapped_intronic'] + obs['reads_mapped_intronic_as']
        obs['NUM_TRANSCRIPTS'] = num_transcripts
        obs['num_transcripts'] = num_transcripts
        obs['num_reads'] = mapped_reads
        obs['totalReads'] = total_reads
        obs['mappedReads'] = mapped_reads
        obs['hqMappedReads'] = mapped_reads
        obs['hqMappedReadsNoPCRDupes'] = mapped_reads
        obs['pct_coding'] = (obs['reads_mapped_exonic'] + obs['reads_mapped_exonic_as']) / mapped_reads
        obs['pct_intronic'] = (obs['reads_mapped_intronic'] + obs['reads_mapped_intronic_as']) / mapped_reads
        obs['pct_intergenic'] = obs['reads_mapped_intergenic'] / mapped_reads
        obs['pct_mt'] = obs['reads_mapped_mitochondrial'] / mapped_reads
        obs['pct_genic'] = obs['pct_coding'] + obs['pct_intronic']
        obs['pct_ribosomal'] = 0
        obs['pct_utr'] = 0

        obs['pct_coding'] = obs['pct_coding'].round(4)
        obs['pct_intronic'] = obs['pct_intronic'].round(4)
        obs['pct_intergenic'] = obs['pct_intergenic'].round(4)
        obs['pct_mt'] = obs['pct_mt'].round(4)
        obs['pct_genic'] = obs['pct_genic'].round(4)
        obs['pct_ribosomal'] = obs['pct_ribosomal'].round(4)
        obs['pct_utr'] = obs['pct_utr'].round(4)

        if ~{true="True" false="False" defined(output_h5ad_path)}:
            print('writing output h5ad', file=sys.stderr)
            adata.write('~{default="/dev/null" output_h5ad_path}')

        if ~{true="True" false="False" defined(output_mtx_path)}:
            print('writing output mtx', file=sys.stderr)
            mmwrite('~{output_mtx_txt}', matrix)
        if ~{true="True" false="False" defined(output_barcodes_path)}:
            print('writing output barcodes', file=sys.stderr)
            adata.obs_names.to_series().to_csv('~{output_barcodes_txt}', header=False, index=False)
        if ~{true="True" false="False" defined(output_features_path)}:
            print('writing output features', file=sys.stderr)
            features_df = pd.DataFrame(adata.var_names.to_series(), columns=['gene_id'])
            features_df['gene_name'] = features_df['gene_id']
            features_df['feature_type'] = 'Gene Expression'
            features_df.to_csv('~{output_features_txt}', sep='\t', header=False, index=False)

        if ~{true="True" false="False" defined(output_digital_expression_path)}:
            print('generating digital expression', file=sys.stderr)
            dge = pd.DataFrame.sparse.from_spmatrix(matrix)
            dge.columns = adata.obs_names
            dge.index = adata.var_names
            dge.index.name = 'GENE'
            dge_path = '~{output_digital_expression_txt}'
            with open(dge_path, 'w') as f:
                f.write('#DGE\tVERSION:1.1\tEXPRESSION_FORMAT:raw\n')
                dge.to_csv(dge_path, sep='\t', mode='a')

        if ~{true="True" false="False" defined(output_digital_expression_summary_path)}:
            print('generating digital expression summary', file=sys.stderr)
            dge_summary = obs[['NUM_GENIC_READS', 'NUM_TRANSCRIPTS', 'NUM_GENES']]
            dge_summary.index.name = 'CELL_BARCODE'
            dge_summary = dge_summary.sort_values(by='NUM_GENIC_READS', ascending=False)
            dge_summary_path = '~{default="/dev/null" output_digital_expression_summary_path}'
            with open(dge_summary_path, 'w') as f:
                f.write('## METRICS CLASS\torg.broadinstitute.dropseqrna.barnyard.DigitalExpression\$DESummary\n')
            dge_summary.to_csv(dge_summary_path, sep='\t', mode='a')

        if ~{true="True" false="False" defined(output_reads_per_cell_file_path)}:
            print('generating reads per cell', file=sys.stderr)
            reads_per_cell = obs[['num_reads', 'cell_names']]
            reads_per_cell = reads_per_cell.sort_values(by='num_reads', ascending=False)
            reads_per_cell.to_csv('~{output_reads_per_cell_file_txt}', sep='\t', header=False, index=False)

        if ~{true="True" false="False" defined(output_read_quality_metrics_path)}:
            print('generating read quality metrics', file=sys.stderr)
            read_qualities = obs[['totalReads', 'mappedReads', 'hqMappedReads', 'hqMappedReadsNoPCRDupes']]
            read_quality_metrics = pd.DataFrame(read_qualities.sum()).T
            read_quality_metrics.insert(0, 'aggregate', 'all')
            read_quality_metrics_path = '~{default="/dev/null" output_read_quality_metrics_path}'
            with open(read_quality_metrics_path, 'w') as f:
                f.write('## METRICS CLASS\torg.broadinstitute.dropseqrna.metrics.ReadQualityMetrics\n')
            read_quality_metrics.to_csv(read_quality_metrics_path, sep='\t', mode='a', index=False)

        if ~{true="True" false="False" defined(output_cell_selection_report_path)}:
            print('generating cell selection report', file=sys.stderr)
            cell_selection_report = obs[['num_transcripts', 'num_reads', 'pct_ribosomal', 'pct_coding', 'pct_intronic',
                                         'pct_intergenic', 'pct_utr', 'pct_genic', 'pct_mt']]
            cell_selection_report.index.name = 'cell_barcode'
            cell_selection_report = cell_selection_report.sort_values(by='num_transcripts', ascending=False)
            cell_selection_report.to_csv('~{default="/dev/null" output_cell_selection_report_path}', sep='\t')

        print('done', file=sys.stderr)
        EOF

        ~{if defined(output_digital_expression_path) then "gzip -k -n " + output_digital_expression_txt else ""}
        ~{if defined(output_reads_per_cell_file_path) then "gzip -k -n " + output_reads_per_cell_file_txt else ""}
        ~{if defined(output_mtx_path) then "gzip -k -n " + output_mtx_txt else ""}
        ~{if defined(output_barcodes_path) then "gzip -k -n " + output_barcodes_txt else ""}
        ~{if defined(output_features_path) then "gzip -k -n " + output_features_txt else ""}
    >>>

    runtime {
        docker: docker
        cpu: cpu
        memory: memory_mb + " MB"
        disks: "local-disk " + disk_gb + " HDD"
        preemptible: preemptible
    }

    output {
        File? output_h5ad = output_h5ad_path
        File? output_mtx = output_mtx_path
        File? output_barcodes = output_barcodes_path
        File? output_features = output_features_path
        File? output_digital_expression = output_digital_expression_path
        File? output_digital_expression_summary = output_digital_expression_summary_path
        File? output_reads_per_cell_file = output_reads_per_cell_file_path
        File? output_read_quality_metrics = output_read_quality_metrics_path
        File? output_cell_selection_report = output_cell_selection_report_path
    }
}
