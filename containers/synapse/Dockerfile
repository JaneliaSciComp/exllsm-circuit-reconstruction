FROM registry.int.janelia.org/janeliascicomp/matlab-centos8:2020b as builder

USER root

WORKDIR /tmp-compile
COPY scripts/matlab /tmp-compile/matlab

RUN mkdir /tmp-compile/dest && \
    /usr/local/MATLAB/bin/mcc \
    -W python:watershed \
    -d /tmp-compile/dest \
    -v \
    -I /tmp-compile/matlab \
    closing_watershed.m

FROM centos:8

ENV MATLAB_RELEASE=R2020b
ENV MATLAB_VERSION=v99
ENV DOWNLOAD_FILENAME=MATLAB_Runtime_R2020b_Update_3_glnxa64.zip

ENV DOWNLOAD_MATLAB_URL=https://ssd.mathworks.com/supportfiles/downloads/${MATLAB_RELEASE}/Release/3/deployment_files/installer/complete/glnxa64/MATLAB_Runtime_R2020b_Update_3_glnxa64.zip
ENV DOWNLOAD_CONDA_URL=https://repo.continuum.io/miniconda/Miniconda3-latest-Linux-x86_64.sh

ENV NVIDIA_VISIBLE_DEVICES=all
ENV NVIDIA_DRIVER_CAPABILITIES=all

RUN dnf install -y \
        wget unzip

RUN dnf install -y \
        atk \
        gsound \
        gdk-pixbuf2 \
        gtk2 \
        libnsl \
        libX11 \
        libX11-xcb \
        libXScrnSaver \
        libXxf86vm \
        nss \
        zlib

RUN dnf install -y \
        libXt libXtst libXext libXmu libXrandr libXrender libXcomposite

RUN mkdir /tmp-install && \
    cd /tmp-install && \
    wget --quiet ${DOWNLOAD_MATLAB_URL} && \
    unzip ${DOWNLOAD_FILENAME} && \
    rm -f ${DOWNLOAD_FILENAME} && \
    ./install -mode silent -agreeToLicense yes && \
    wget ${DOWNLOAD_CONDA_URL} -O miniconda-install.sh && \
    bash miniconda-install.sh -b -p /miniconda && \
    rm miniconda-install.sh

WORKDIR /app

ENV PATH=/miniconda/bin:${PATH}

ENV LD_LIBRARY_PATH=$LD_LIBRARY_PATH:\
/usr/local/MATLAB/MATLAB_Runtime/${MATLAB_VERSION}/runtime/glnxa64:\
/usr/local/MATLAB/MATLAB_Runtime/${MATLAB_VERSION}/bin/glnxa64:\
/usr/local/MATLAB/MATLAB_Runtime/${MATLAB_VERSION}/sys/os/glnxa64:\
/usr/local/MATLAB/MATLAB_Runtime/${MATLAB_VERSION}/sys/opengl/lib/glnxa64:\
/usr/local/MATLAB/MATLAB_Runtime/${MATLAB_VERSION}/sys/java/jre/glnxa64/jre/lib/amd64/server:\
/usr/local/MATLAB/MATLAB_Runtime/${MATLAB_VERSION}/sys/java/jre/glnxa64/jre/lib/amd64
ENV XAPPLRESDIR=/usr/local/MATLAB/MATLAB_Runtime/${MATLAB_VERSION}/X11/app-defaults
ENV MCR_CACHE_VERBOSE=true

COPY --from=builder /tmp-compile/dest /tmp-install/commpiled-watershed

COPY conda-requirements.yml /tmp-install

RUN conda config --set always_yes yes --set changeps1 no && \
    conda update -q conda

RUN conda install python=3.8

RUN conda env update -n base -f /tmp-install/conda-requirements.yml

RUN cd /usr/local/MATLAB/MATLAB_Runtime/${MATLAB_VERSION}/toolbox/compiler_sdk/pysdk_py && \
    python setup.py install && \
    cd /tmp-install/commpiled-watershed && \
    python setup.py install

COPY scripts/python /app/synapse/scripts

RUN rm -rf /tmp-install

WORKDIR /app/synapse