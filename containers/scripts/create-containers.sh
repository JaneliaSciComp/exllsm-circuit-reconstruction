DIR=$(cd "$(dirname "$0")"; pwd)

source ${DIR}/container-versions.sh

RUNNER=
FORCE=

help_cmd="$0 [-n] [-f] [-h|--help]"

while [[ $# > 0 ]]; do
    key="$1"
    shift # past the key
    case $key in
        -n)
            RUNNER="echo"
            ;;
        -f)
            FORCE="--no-cache"
            ;;
        -h|--help)
            echo "${help_cmd}"
            exit 0
            ;;
        *)
            echo "Unknown flag ${key}"
            echo "${help_cmd}"
            exit 1
            ;;
    esac
done


${RUNNER} docker build \
    ${FORCE} \
    --build-arg SYNAPSE_DETECTOR_GIT_TAG=${synapse_git_hash} \
    -t registry.int.janelia.org/exm-analysis/synapse:${synapse_version} \
    -t public.ecr.aws/janeliascicomp/exm-analysis/synapse:${synapse_version} \
    containers/synapse

${RUNNER} docker build \
    ${FORCE} \
    -t registry.int.janelia.org/exm-analysis/synapse-dask:${synapse_dask_version} \
    -t public.ecr.aws/janeliascicomp/exm-analysis/synapse-dask:${synapse_dask_version} \
    containers/synapse-dask

${RUNNER} docker build \
    ${FORCE} \
    --build-arg NEURON_SEGMENTATION_GIT_TAG=${neuron_segmentation_git_hash} \
    -t registry.int.janelia.org/exm-analysis/neuron-segmentation:${neuron_segmentation_version} \
    -t public.ecr.aws/janeliascicomp/exm-analysis/neuron-segmentation:${neuron_segmentation_version} \
    containers/neuron-segmentation

${RUNNER} docker build \
    ${FORCE} \
    --build-arg STITCHING_SPARK_GIT_TAG=${stitching_git_hash} \
    -t registry.int.janelia.org/exm-analysis/stitching:${stitching_version} \
    -t public.ecr.aws/janeliascicomp/exm-analysis/stitching:${stitching_version} \
    containers/stitching

${RUNNER} docker build \
    ${FORCE} \
    --build-arg STITCHING_SPARK_GIT_TAG=${n5_spark_tools_git_hash} \
    -t registry.int.janelia.org/exm-analysis/n5-spark-tools:${n5_spark_tools_version} \
    -t public.ecr.aws/janeliascicomp/exm-analysis/n5-spark-tools:${n5_spark_tools_version} \
    containers/n5-spark-tools
