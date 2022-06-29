DIR=$(cd "$(dirname "$0")"; pwd)

source ${DIR}/container-versions.sh

REPO=$1

if [[ -z ${REPO} ]] ; then
    REPO=registry.int.janelia.org/exm-analysis
elif [[ "${REPO}" == "aws" ]] ; then
    REPO=public.ecr.aws/janeliascicomp/exm-analysis
fi

RUNNER=echo

${RUNNER} docker push ${REPO}/synapse:${synapse_version}
${RUNNER} docker push ${REPO}/synapse-dask:${synapse_dask_version}
${RUNNER} docker push ${REPO}/neuron-segmentation:${neuron_segmentation_version}
${RUNNER} docker push ${REPO}/stitching:${stitching_version}
${RUNNER} docker push ${REPO}/n5-spark-tools:${n5_spark_tools_version}
