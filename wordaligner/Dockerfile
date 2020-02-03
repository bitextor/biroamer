FROM ubuntu:18.04


RUN apt update && apt upgrade -y && \
    apt install -y \
      build-essential \
      git \
      subversion \
      automake \
      libtool \
      zlib1g-dev \
      libboost-all-dev \
      libbz2-dev \
      liblzma-dev \
      python-dev \
      graphviz \
      imagemagick \
      make \
      cmake \
      libgoogle-perftools-dev \
      autoconf \
      doxygen \
      gawk \
      parallel && \
    echo "will cite" | parallel --citation && \
    cd /opt && \
    git clone https://github.com/moses-smt/mgiza.git && \
    cd mgiza/mgizapp && \
    cmake -DCMAKE_INSTALL_PREFIX=/usr/local/bin . && \
    make -j$(getconf _NPROCESSORS_ONLN) install && \
    cd /opt && \
    git clone https://github.com/moses-smt/mosesdecoder.git && \
    cd mosesdecoder && \
    bjam -j$(getconf _NPROCESSORS_ONLN) && \
    apt clean

COPY tools /opt/tools
     

ENV LANG C.UTF-8