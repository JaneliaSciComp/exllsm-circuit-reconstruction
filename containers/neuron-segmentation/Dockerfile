# Create final image
FROM condaforge/mambaforge as builder

# ps is needed by nextflow to collect task metrics
RUN apt-get install -y procps

COPY conda-requirements.yml /tmp/

RUN mamba env create -n myenv python=3.9 -f /tmp/conda-requirements.yml
