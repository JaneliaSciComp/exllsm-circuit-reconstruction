FROM janeliascicomp/builder:1.2.1 as app-builder
ARG SYNAPSE_DETECTOR_GIT_TAG=master

# Checkout and build the code
WORKDIR /tmp/app
RUN git clone --branch $SYNAPSE_DETECTOR_GIT_TAG --depth 1 \
        https://github.com/JaneliaSciComp/SynapseDetectorDNN.git . \
    && git submodule update --init --recursive \
    && /usr/local/bin/buildinfo.sh


FROM janeliascicomp/matlab-centos8:2020b as matlab-builder
USER root

WORKDIR /tmp-compile
COPY --from=app-builder /tmp/app/inference/matlab /tmp-compile/matlab

RUN mkdir /tmp-compile/dest && \
    cd /tmp-compile/dest && \
    /usr/local/MATLAB/bin/mcc \
    -W python:watershed \
    -d /tmp-compile/dest \
    -v \
    -I /tmp-compile/matlab \
    /tmp-compile/matlab/closing_watershed.m \
    /tmp-compile/matlab/close_and_watershed_transform.m


FROM centos:8

ENV MATLAB_RELEASE=R2020b
ENV MATLAB_VERSION=v99
ENV DOWNLOAD_FILENAME=MATLAB_Runtime_R2020b_Update_5_glnxa64.zip
ENV DOWNLOAD_MATLAB_URL=https://ssd.mathworks.com/supportfiles/downloads/${MATLAB_RELEASE}/Release/5/deployment_files/installer/complete/glnxa64/${DOWNLOAD_FILENAME}
ENV DOWNLOAD_CONDA_URL=https://repo.continuum.io/miniconda/Miniconda3-latest-Linux-x86_64.sh

ENV NVIDIA_VISIBLE_DEVICES=all
ENV NVIDIA_DRIVER_CAPABILITIES=all

RUN dnf update -y && \
    dnf install -y dnf-utils

RUN dnf -y install --nogpgcheck \
        https://download.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm \
        https://download1.rpmfusion.org/free/el/rpmfusion-free-release-8.noarch.rpm \
        https://download1.rpmfusion.org/nonfree/el/rpmfusion-nonfree-release-8.noarch.rpm

RUN dnf group install -y "Development Tools" && \
    dnf install -y \
        ca-certificates \
        alsa-lib \
        atk \
        fontconfig \
        gsound \
        gdk-pixbuf2 \
        gtk3 \
        libSM \
        libsndfile \
        libX11 \
        libX11-xcb \
        libxcb \
        libXcomposite \
        libXcursor \
        libXdamage \
        libXext \
        libXfixes \
        libXft \
        libXi \
        libXinerama \
        libXrandr \
        libXrender \
        libXt \
        libXtst \
        libXxf86vm \
        procps-ng \
        zlib

RUN dnf install -y \
        wget unzip which GraphicsMagick

WORKDIR /tmp-install

RUN wget --quiet ${DOWNLOAD_MATLAB_URL} && \
    unzip ${DOWNLOAD_FILENAME} && \
    rm -f ${DOWNLOAD_FILENAME} && \
    ./install -mode silent -agreeToLicense yes

RUN wget ${DOWNLOAD_CONDA_URL} -O miniconda-install.sh && \
    bash miniconda-install.sh -b -p /miniconda && \
    rm miniconda-install.sh

ENV PATH=/miniconda/bin:${PATH}

ENV LD_LIBRARY_PATH=$LD_LIBRARY_PATH:\
/usr/local/MATLAB/MATLAB_Runtime/${MATLAB_VERSION}/runtime/glnxa64:\
/usr/local/MATLAB/MATLAB_Runtime/${MATLAB_VERSION}/bin/glnxa64:\
/usr/local/MATLAB/MATLAB_Runtime/${MATLAB_VERSION}/sys/os/glnxa64:\
/usr/local/MATLAB/MATLAB_Runtime/${MATLAB_VERSION}/sys/opengl/lib/glnxa64

ENV MCR_CACHE_VERBOSE=true

RUN conda config --set always_yes yes --set changeps1 no && \
    conda update -q conda

RUN conda install python=3.8

COPY --from=app-builder /tmp/app/inference/environment.yml /tmp-install

# Remove libtiff because it conflicts with the one required by matlab
RUN conda env update -n base -f /tmp-install/environment.yml --prune  && \
    conda remove libtiff --force

WORKDIR /scripts

RUN cd /usr/local/MATLAB/MATLAB_Runtime/${MATLAB_VERSION}/toolbox/compiler_sdk/pysdk_py && \
    python setup.py install

COPY --from=matlab-builder /tmp-compile/dest /tmp-install/compiled-watershed

RUN cd /tmp-install/compiled-watershed && \
    python setup.py install && \
    rm -rf /tmp-install

COPY --from=app-builder /tmp/app/inference/python /scripts
COPY --from=app-builder /tmp/app/inference/*.sh /scripts
COPY --from=app-builder /buildinfo /
RUN chmod 555 /scripts/*.sh

