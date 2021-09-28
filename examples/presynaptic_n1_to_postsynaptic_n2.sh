#!/bin/bash
DIR=$(cd "$(dirname "$0")"; pwd)
pushd $DIR/..

# The temporary directory needs to have 10 GB to store large Docker images
export TMPDIR="${TMPDIR:-/opt/tmp}"
export SINGULARITY_TMPDIR="${SINGULARITY_TMPDIR:-$TMPDIR}"

#NEURON="/nrs/dickson/lillvis/temp/ExM/DA1/20201001/images/VVD/fullresmasks/ch0_5t_30vx_9t_substack_crop_connected_20vx_x4"
#POST="/nrs/dickson/lillvis/temp/ExM/DA1/20201001/images/slice-tiff-s0/ch1_substack_crop"
#PRE="/nrs/dickson/lillvis/temp/ExM/DA1/20201001/images/slice-tiff-s0/ch2_substack_crop"

NEURON="/nrs/scicompsoft/rokicki/exm/workflow_c/neuron"
POST="/nrs/scicompsoft/rokicki/exm/workflow_c/post"
PRE="/nrs/scicompsoft/rokicki/exm/workflow_c/pre"
RES_DIR="/nrs/scicompsoft/rokicki/exm/workflow_c/results"
MODEL="/groups/dickson/dicksonlab/lillvis/ExM/Ding-Ackerman/crops-for-training_Oct2018/DING/model_DNN/saved_unet_model_2020/unet_model_synapse2020_6/unet_model_synapse2020_6.whole.h5"
MODEL_DIR=$(dirname $MODEL)

PROFILE=lsf
PROJECT_CODE="dickson"
BIND_FLAGS="-B /scratch -B $NEURON -B $POST -B $PRE -B $RES_DIR -B $MODEL_DIR"

mkdir -p $RES_DIR
./synapse_pipeline.nf \
        -profile ${PROFILE} \
        --lsf_opts "-P $PROJECT_CODE" \
        --runtime_opts "${BIND_FLAGS}" \
        --pipeline "presynaptic_n1_to_postsynaptic_n2" \
        --block_size "500,500,500" \
        --volume_partition_size "500" \
        --synapse_model "$MODEL" \
        --n1 "$NEURON" \
        --postsynapse "$POST" \
        --presynapse "$PRE" \
        --output_dir "${RES_DIR}/presynaptic_n1_to_postsynaptic_n2" \
        --presynaptic_stage2_threshold "400" \
        --presynaptic_stage2_percentage "0.5" \
        --postsynaptic_stage3_threshold "200" \
        --postsynaptic_stage3_percentage "0.001" \
        --postsynaptic_stage4_threshold "400" \
        --postsynaptic_stage4_percentage "0.001" \
        -with-tower http://nextflow.int.janelia.org/api "$@"

popd
