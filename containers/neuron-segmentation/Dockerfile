# Create final image
FROM condaforge/mambaforge as builder

# ps is needed by nextflow to collect task metrics
RUN apt-get install -y procps

COPY conda-requirements.yml /tmp/

ENV NVIDIA_VISIBLE_DEVICES=all
ENV NVIDIA_DRIVER_CAPABILITIES=all

RUN mamba env create -n myenv python=3.9 -f /tmp/conda-requirements.yml

RUN conda clean --tarballs \
    && mkdir -p /opt/conda/envs/myenv/etc/conda/activate.d \
    # It's necessary to set TMPDIR for running with Singularity, because /opt/conda will be read-only
    && echo "export TMPDIR=/tmp" > /opt/conda/envs/myenv/etc/conda/activate.d/env_vars.sh

COPY scripts /app

RUN echo "#!/bin/bash" >> /entrypoint.sh \
    && echo "source /opt/conda/etc/profile.d/conda.sh" >> /entrypoint.sh \
    && echo "SCRIPT_NAME=\$1; shift" >> /entrypoint.sh \
    && echo "conda activate myenv" >> /entrypoint.sh \
    && echo 'python /app/${SCRIPT_NAME}.py "$@"' >> /entrypoint.sh \
    && chmod +x /entrypoint.sh
