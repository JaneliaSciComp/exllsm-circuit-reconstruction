#!/bin/bash
DIR=$(cd "$(dirname "$0")"; pwd)
pushd $DIR/..

# The temporary directory needs to have 10 GB to store large Docker images
export TMPDIR="${TMPDIR:-/opt/tmp}"
export SINGULARITY_TMPDIR="${SINGULARITY_TMPDIR:-$TMPDIR}"

PROFILE=lsf
CONTAINER_ENV_ARG="-e --env \"USER=$USER\""
RES_DIR="/nrs/scicompsoft/rokicki/exm/results"
NEURON="/nrs/dickson/lillvis/temp/ExM/DA1/20201001/images/VVD/fullresmasks/ch0_5t_30vx_9t_substack_crop_connected_20vx_x4"
MODEL="/groups/dickson/dicksonlab/lillvis/ExM/Ding-Ackerman/crops-for-training_Oct2018/DING/model_DNN/saved_unet_model_2020/unet_model_synapse2020_6/unet_model_synapse2020_6.whole.h5"
BIND_FLAGS="-B $RES_DIR -B /scratch -B /nrs/scicompsoft/rokicki -B /groups/dickson/dicksonlab/lillvis -B /nrs/dickson/lillvis"
PROJECT_CODE="dickson"


./synapse_pipeline.nf \
        -profile ${PROFILE} \
        --lsf_opts "-P $PROJECT_CODE" \
        --runtime_opts "-e ${BIND_FLAGS} ${CONTAINER_ENV_ARG}" \
        --pipeline "presynaptic_n1_to_postsynaptic_n2" \
        --block_size "500,500,500" \
        --volume_partition_size "500" \
        --synapse_model "$MODEL" \
        --n1_stack_dir "$NEURON" \
        --post_synapse_stack_dir "/nrs/dickson/lillvis/temp/ExM/DA1/20201001/images/slice-tiff-s0/ch1_substack_crop" \
        --pre_synapse_stack_dir "/nrs/dickson/lillvis/temp/ExM/DA1/20201001/images/slice-tiff-s0/ch2_substack_crop" \
        --output_dir "${RES_DIR}/presynaptic_n1_to_postsynaptic_n2" \
        --presynaptic_stage2_threshold "400" \
        --presynaptic_stage2_percentage "0.5" \
        --postsynaptic_stage2_threshold "200" \
        --postsynaptic_stage2_percentage "0.001" \
        --postsynaptic_stage3_threshold "400" \
        --postsynaptic_stage3_percentage "0.001" \
        -with-tower http://nextflow.int.janelia.org/api "$@"

popd
