DIR=$(cd "$(dirname "$0")"; pwd)

source ${DIR}/container-versions.sh

RUNNER=
REPO=

help_cmd="$0 [-n] [-r <repo>] [-h|--help]"

while [[ $# > 0 ]]; do
    key="$1"
    shift # past the key
    case $key in
        -n)
            RUNNER="echo"
            ;;
        -r)
            REPO="$1"
	    shift
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

if [[ -z ${REPO} ]] ; then
    REPO=registry.int.janelia.org/exm-analysis
elif [[ "${REPO}" == "janelia" ]] ; then
    REPO=registry.int.janelia.org/exm-analysis
elif [[ "${REPO}" == "aws" ]] ; then
    REPO=public.ecr.aws/janeliascicomp/exm-analysis
fi

${RUNNER} docker push ${REPO}/synapse:${synapse_version}
${RUNNER} docker push ${REPO}/synapse-dask:${synapse_dask_version}
${RUNNER} docker push ${REPO}/neuron-segmentation:${neuron_segmentation_version}
${RUNNER} docker push ${REPO}/stitching:${stitching_version}
${RUNNER} docker push ${REPO}/n5-spark-tools:${n5_spark_tools_version}
