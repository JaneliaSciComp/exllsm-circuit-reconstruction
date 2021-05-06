#!/bin/bash
DIR=$(cd "$(dirname "$0")"; pwd)
pushd $DIR/..

# The temporary directory needs to have 10 GB to store large Docker images
export TMPDIR="${TMPDIR:-/opt/tmp}"
export SINGULARITY_TMPDIR="${SINGULARITY_TMPDIR:-$TMPDIR}"

PROFILE=lsf
CONTAINER_ENV_ARG="-e --env \"USER=$USER\""
RES_DIR="/nrs/scicompsoft/rokicki/exm/results"
MODEL="/groups/dickson/dicksonlab/lillvis/ExM/Ding-Ackerman/crops-for-training_Oct2018/DING/model_DNN/saved_unet_model_2020/unet_model_synapse2020_6/unet_model_synapse2020_6.whole.h5"
BIND_FLAGS="-B /scratch -B /nrs/scicompsoft/rokicki -B $RES_DIR -B /groups/dickson/dicksonlab/lillvis"
PROJECT_CODE="dickson"

./synapse_pipeline.nf \
         -profile ${PROFILE} \
         --lsf_opts "-P $PROJECT_CODE" \
         --runtime_opts "-e ${BIND_FLAGS} ${CONTAINER_ENV_ARG}" \
         --pipeline 'presynaptic_n1_to_n2' \
         --block_size '500,500,500' \
         --volume_partition_size 500 \
         --synapse_model $MODEL \
         --pre_synapse_stack_dir ${RES_DIR}/stitching/slice-tiff-s0/ch0 \
         --n1_stack_dir ${RES_DIR}/stitching/slice-tiff-s0/ch1 \
         --n2_stack_dir ${RES_DIR}/stitching/slice-tiff-s0/ch2 \
         --output_dir ${RES_DIR}/presynaptic_n1_to_n2 \
         -with-tower http://nextflow.int.janelia.org/api "$@"

popd
