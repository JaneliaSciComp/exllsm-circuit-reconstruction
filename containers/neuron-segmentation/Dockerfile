# Create final image
FROM janeliascicomp/builder:1.2.1 as app-builder
ARG NEURON_SEGMENTATION_GIT_TAG=master

# Checkout and build the code
WORKDIR /tmp/app/neuron-segmentation
# clone the repo and the desired version but then remove
# the h5 model because that will only increase the size of the container
RUN git clone --branch ${NEURON_SEGMENTATION_GIT_TAG} --depth 1 https://github.com/JaneliaSciComp/neuron-segmentation.git . \
    && /usr/local/bin/buildinfo.sh \
    && rm -rf *.h5 .git

FROM condaforge/mambaforge

# ps is needed by nextflow to collect task metrics
RUN apt-get install -y procps

WORKDIR /tmp/tmp-install

ENV NVIDIA_VISIBLE_DEVICES=all
ENV NVIDIA_DRIVER_CAPABILITIES=all

COPY --from=app-builder /buildinfo /
COPY --from=app-builder /tmp/app/neuron-segmentation /tmp/tmp-install/neuron-segmentation

RUN mamba create -n myenv python=3.9 -y \
 && mamba env update \
        -n myenv \
        -f /tmp/tmp-install/neuron-segmentation/conda-requirements.yml

RUN conda clean --tarballs \
    && mkdir -p /opt/conda/envs/myenv/etc/conda/activate.d \
    # It's necessary to set TMPDIR for running with Singularity, because /opt/conda will be read-only
    && echo "export TMPDIR=/tmp" > /opt/conda/envs/myenv/etc/conda/activate.d/env_vars.sh

WORKDIR /app
RUN cp -a /tmp/tmp-install/neuron-segmentation python \
    && rm -rf /tmp/tmp-install

RUN echo "#!/bin/bash" >> /entrypoint.sh \
    && echo "source /opt/conda/etc/profile.d/conda.sh" >> /entrypoint.sh \
    && echo "SCRIPT_NAME=\$1; shift" >> /entrypoint.sh \
    && echo "conda activate myenv" >> /entrypoint.sh \
    && echo 'python /app/python/${SCRIPT_NAME}.py "$@"' >> /entrypoint.sh \
    && chmod +x /entrypoint.sh
