# Parameters

The pipeline supports many types of parameters for customization to your compute environment and data. These can all be specified on the command line using the standard syntax `--argument="value"` or `--argument "value"`. You can also use any option supported by Nextflow itself. Note that certain arguments (i.e. those interpreted by Nextflow) use a single dash instead of two.

## Environment Variables

You can export variables into your environment before calling the pipeline, or set them on the same line like this:

    TMPDIR=/opt/tmp ./examples/stitching.sh

Note that the example scripts set all these directories relative to the TMPDIR by default, so setting TMPDIR sets everything else to the same location.

| Variable   | Default | Description                                                                           |
|------------|---------|---------------------------------------------------------------------------------------|
| TMPDIR | /tmp | Directory used for temporary files by certain processes like MATLAB's MCR Cache. |
| SINGULARITY_TMPDIR | /tmp | Directory where Docker images are downlaoded and converted to Singularity Image Format. Needs to be large enough to accomodate several GB, so moving it out of /tmp is sometimes necessary. |
| SPARK_LOCAL_DIR | /tmp | Directory used for temporary storage by Spark (in the stitching module). |

## Global Parameters

| Argument   | Default | Description                                                                           |
|------------|---------|---------------------------------------------------------------------------------------|
| -profile | standard | Configuration profile to use (Valid values: standard, lsf, localdocker) |
| -with-tower | | [Nextflow Tower](https://tower.nf) URL for monitoring |
| -work-dir | ./work | Nextflow working directory where all intermediate files are saved |
| --spark_work_dir | | Path to directory containing Spark working files and logs during stitching |
| --runtime_opts | | Runtime options for Singularity must include mounts for any directory paths you are using. You can also pass the --nv flag here to make use of NVIDIA GPU resources. For example, `--nv -B /your/data/dir -B /your/output/dir` | 
| --lsf_opts | | Any extra options to pass to bsub when running jobs on LSF |
| &#x2011;&#x2011;singularity_cache_dir | | Path to directory used for caching Singularity container images. If running in distributed mode, this path must be accessible from all cluster nodes. |
