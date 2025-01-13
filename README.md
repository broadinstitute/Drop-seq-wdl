# Drop-seq WDL

WDL for analyzing [Drop-seq](http://mccarrolllab.com/dropseq/) data

Drop-seq questions may be directed to [dropseq@gmail.com](mailto:dropseq@gmail.com).  
You may also use this address to be added to the Drop-seq Google group.

See the [Drop-seq GitHub repository](https://github.com/broadinstitute/Drop-seq) for more information on the tools.

# Overview

* These WDLs are considered early but usable previews, subject to extensive changes!

* WDLs are separated by into pipelines and tasks
    * Pipelines are the top-level WDLs that define the executable workflows.
    * Some pipelines are further divided into sub-workflows.
    * Tasks are the individual steps that are called by the pipelines that execute a single tool.
    * There are experimental "combined" WDLs that aggregate multiple pipelines.

* The WDLs are designed to
    * Run on [Terra.bio](https://terra.bio) platform and its underlying [Cromwell](https://cromwell.readthedocs.io/)
      workflow management system.
    * Written in WDL version 1.0.
    * Optimize costs on [Google Cloud Platform](https://cloud.google.com/) but may run on other platforms.
    * Compliment and extend pipelines from
        * [WARP](https://broadinstitute.github.io/warp/), especially
          [Optimus](https://broadinstitute.github.io/warp/docs/Pipelines/Optimus_Pipeline/README).
        * [CellBender Remove Background](https://cellbender.readthedocs.io/) (CBRB)
    * Optimize Google Compute memory while leaving a buffer, since as of November 2024 Terra.bio
      [does not retry](https://support.terra.bio/hc/en-us/community/posts/25689049423259/comments/27763244299163)
      any host VM memory failures. Java Virtual Machines are sized to use a fraction of the host VM memory.

* Tasks contain a mix of Drop-seq tools and other tools
    * Drop-seq tools are from the Drop-seq GitHub repository.
    * Other tools are from the [Broad Institute GATK](https://gatk.broadinstitute.org/) and other sources.
    * Tasks may expose all or only some of the tool parameters.

# Workflows

| Workflow                  | Summary                                         |
|---------------------------|-------------------------------------------------|
| `optimus_post_processing` | Converts Optimus outputs to Drop-seq inputs     |
| `dropseq_cbrb`            | Estimates parameters then invokes CBRB          |
| `cell_selection`          | Sub-selects barcodes that captured nuclei       |
| `standard_analysis`       | Assigns nuclei to donors and detects doublets   |
| `cell_classification`     | Classifies cells based on their gene expression |
