# Parameters

The pipeline supports many types of parameters for customization to your compute environment and data. These can all be specified on the command line using the standard syntax `--argument="value"` or `--argument "value"`. You can also use any option supported by Nextflow itself. Note that certain arguments (i.e. those interpreted by Nextflow) use a single dash instead of two.

## Environment Variables

You can export variables into your environment before calling the pipeline, or set them on the same line like this:

    TMPDIR=/opt/tmp ./examples/demo_small.sh /opt/demo_small

Note that the demo scripts set all these directories relative to the TMPDIR by default, so setting TMPDIR sets everything else to the same location.

| Variable   | Default | Description                                                                           |
|------------|---------|---------------------------------------------------------------------------------------|
| TMPDIR | /tmp | Directory used for temporary files by certain processes like MATLAB's MCR Cache. |
| SINGULARITY_TMPDIR | /tmp | Directory where Docker images are downlaoded and converted to Singularity Image Format. Needs to be large enough to accomodate several GB, so moving it out of /tmp is sometimes necessary. |
| SINGULARITY_CACHEDIR | $HOME/.singularity_cache | Directory where Singularity images are cached. This needs to be accessible from all nodes. |
| SPARK_LOCAL_DIR | /tmp | Directory used for temporary storage by Spark (in the stitching module). |

## Global Parameters

| Argument   | Default | Description                                                                           |
|------------|---------|---------------------------------------------------------------------------------------|
| --spark_work_dir | | Path to directory containing Spark working files and logs during stitching |
| &#x2011;&#x2011;segmentation_model_dir | | Path to the directory containing the machine learning model for segmentation |
| --runtime_opts | | Runtime options for Singularity must include mounts for any directory paths you are using. You can also pass the --nv flag here to make use of NVIDIA GPU resources. For example, `--nv -B /your/data/dir -B /your/output/dir` | 
| --workdir | ./work | Nextflow working directory where all intermediate files are saved |
| --mfrepo | janeliascicomp (on DockerHub) | Docker Registry and Repository to use for containers | 
| -profile | localsingularity | Configuration profile to use (Valid values: localsingularity, lsf) |
| -with-tower | | [Nextflow Tower](https://tower.nf) URL for monitoring |

