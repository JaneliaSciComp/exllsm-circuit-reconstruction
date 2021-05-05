## Expansion Microscopy Pipeline

This is a pipeline for analyzing expansion microscopy data, consisting of several independent workflows, and integration with [VVD Viewer](https://github.com/takashi310/VVD_Viewer).

## Quick Start

The only software requirements for running this pipeline are [Nextflow](https://www.nextflow.io) (version 20.10.0 or greater) and [Singularity](https://sylabs.io) (version 3.5 or greater). If you are running in an HPC cluster, ask your system administrator to install Singularity on all the cluster nodes.

To [install Nextflow](https://www.nextflow.io/docs/latest/getstarted.html):

    curl -s https://get.nextflow.io | bash 

Alternatively, you can install it as a conda package:

    conda create --name exm -c bioconda nextflow

To [install Singularity](https://sylabs.io/guides/3.7/admin-guide/installation.html) on CentOS Linux:

    sudo yum install singularity

Clone the multifish repository with the following command:

    git clone https://github.com/JaneliaSciComp/expansion-microscopy-pipeline.git

You can now launch a pipeline, e.g.:

    ./stitch_pipeline.nf [arguments]


## Pipeline Overview

This pipeline is containerized and portable across the various platforms supported by [Nextflow](https://www.nextflow.io). So far it has been tested on a standalone Linux workstation and the Janelia compute cluster (IBM Platform LSF). If you run it successfully on any other platform, please let us know so that we can update this documentation.

The pipeline includes the following workflows:
* **[stitching](docs/Stitching.md)** - distributed stitching pipeline including flatfield correction and deconvolution
* **neuron segmentation** - semi-automated workflows for neuron segmentation
* **[synapse prediction](docs/SynapsePrediction.md)** - workflows for synapse masking and prediction
* **VVD converter** - distributed pipeline for converting to VVD format


## Global Parameters

The following parameters are required to run the full pipeline. See the [parameter documentation](docs/Parameters.md) for a complete list of all possible options.

| Argument   | Description                                                                           |
|------------|---------------------------------------------------------------------------------------|
| --runtime_opts | | Runtime options for Singularity must include mounts for any directory paths you are using. You can also pass the --nv flag here to make use of NVIDIA GPU resources. For example, `--nv -B /your/data/dir -B /your/output/dir` | 
| --workdir | ./work | Nextflow working directory where all intermediate files are saved |
| --mfrepo | janeliascicomp (on DockerHub) | Docker Registry and Repository to use for containers | 
| -profile | localsingularity | Configuration profile to use (Valid values: localsingularity, lsf) |
| -with-tower | | [Nextflow Tower](https://tower.nf) URL for monitoring |

## Pipeline Execution

Nextflow supports many different execution engines for portability across platforms and schedulers. We have tested the pipeline using local execution and using the cluster at Janelia Research Campus (running IBM Platform LSF). 

To run this pipeline on a cluster, all input and output paths must be mounted and accessible on all the cluster nodes. 

### Run the pipeline locally

To run the pipeline locally, you can use the standard profile:

    ./main.nf [arguments]

This is equivalent to specifying the localsingularity profile:

    ./main.nf -profile localsingularity [arguments]

### Run the pipeline on IBM Platform LSF 

This example also sets the project flag to demonstrate how to set LSF options.

    ./main.nf -profile lsf --lsf_opts "-P project_code" [arguments]

Usage examples are available in the [examples](examples) directory.

## User Manual

Further detailed documentation is available here:

* [Pipeline Parameters](docs/Parameters.md)
* [Troubleshooting](docs/Troubleshooting.md)
* [Development](docs/Development.md)

## Open Source License

This software is made available under [Janelia's Open Source Software](https://www.janelia.org/open-science/software-licensing) policy which uses the BSD 3-Clause License. 
