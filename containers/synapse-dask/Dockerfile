# Create final image
FROM condaforge/mambaforge as builder

RUN mamba create -n myenv -c conda-forge python=3.8 tqdm numpy=1.20 scikit-image=0.18 \
        zarr=2.7 dask=2021.4 dask-image=0.5.0 -y \
    && conda run -n myenv pip install xarray-multiscale fibsem-tools \
    && conda clean --tarballs \
    && mkdir -p /opt/conda/envs/myenv/etc/conda/activate.d \
    # It's necessary to set TMPDIR for running with Singularity, because /opt/conda will be read-only
    && echo "export TMPDIR=/tmp" > /opt/conda/envs/myenv/etc/conda/activate.d/env_vars.sh

# ps is needed by nextflow to collect task metrics
RUN apt-get install -y procps

COPY scripts /app

RUN echo "#!/bin/bash" >> /entrypoint.sh \
    && echo "source /opt/conda/etc/profile.d/conda.sh" >> /entrypoint.sh \
    && echo "SCRIPT_NAME=\$1; shift" >> /entrypoint.sh \
    && echo "conda activate myenv" >> /entrypoint.sh \
    && echo 'python /app/${SCRIPT_NAME}.py "$@"' >> /entrypoint.sh \
    && chmod +x /entrypoint.sh
