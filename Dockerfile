# Copyright (c) 2024 SIDN Labs
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# 1. Redistributions of source code must retain the above copyright notice, this
#    list of conditions and the following disclaimer.
#
# 2. Redistributions in binary form must reproduce the above copyright notice,
#    this list of conditions and the following disclaimer in the documentation
#    and/or other materials provided with the distribution.
#
# 3. Neither the name of the copyright holder nor the names of its
#    contributors may be used to endorse or promote products derived from
#    this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
# CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
# OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

# First stage: the builder image

ARG UBUNTU_VERSION=22.04
FROM ubuntu:${UBUNTU_VERSION} as build

# This is the PowerDNS version that is Labs-supported, as in: we have a patchfile for it.
ARG PDNS_VERSION=master-20240605
ARG PDNS_COMMIT=9cae233bdc121564af63521a0b862d7f64d911dd
# Use PQClean commit (currently most recent in master at time of writing)
ARG PQCLEAN_COMMIT=0cdedc78dc429ef3dd251257d9f2634e725d0536
ARG SQISIGN_COMMIT=ff34a8cd18b6b131021f5027e2000eb54b98fd1c
ARG MAYO_COMMIT=fc9079fb5ac5cd4af98e3e0f094a0a3cf2a01499
ARG DIRECTORY=/build/workspace

# Two lines to prevent tzdata from blocking us
ARG DEBIAN_FRONTEND=noninteractive
ENV TZ=Europe/Amsterdam

# Install dependencies
RUN apt update && apt install -y --no-install-recommends git build-essential libboost-all-dev libtool make \ 
    pkg-config default-libmysqlclient-dev libssl-dev libluajit-5.1-dev python3-venv curl \ 
    autoconf automake ragel bison flex libcurl4-openssl-dev luajit lua-yaml-dev libyaml-cpp-dev \ 
    libtolua-dev lua5.3 libboost-all-dev libtool lua-yaml-dev libyaml-cpp-dev libcurl4 gawk libsqlite3-dev \
    cmake libgmp-dev cargo
# Adding libsodium-dev as hack to make sure that signerssodium is compiled (incl Falcon code)

ADD patches/patch-powerdns-${PDNS_VERSION}.diff ${DIRECTORY}/patch-powerdns-${PDNS_VERSION}.diff

# Show informative message with number of cores
RUN echo Currently running on $(nproc) cores

# First, clone relevant repositories of PowerDNS and Falcon
RUN mkdir -p ${DIRECTORY}
RUN mkdir -p ~/.ssh && ssh-keyscan -t rsa gitlab.sidnlabs.nl >> ~/.ssh/known_hosts
# Clone PowerDNS repository, checkout VERSION and apply patch
RUN git clone https://github.com/PowerDNS/pdns.git ${DIRECTORY}/pdns
# Clone our own PowerDNS-patched version
RUN cd ${DIRECTORY}/pdns && git fetch --tags && \
    git checkout ${PDNS_COMMIT} && \ 
    git apply ${DIRECTORY}/patch-powerdns-${PDNS_VERSION}.diff
# Now use PQClean
RUN git clone https://github.com/PQClean/PQClean ${DIRECTORY}/PQClean
RUN cd ${DIRECTORY}/PQClean && git checkout ${PQCLEAN_COMMIT}
# Obtain SQIsign
RUN git clone https://github.com/SQISign/the-sqisign ${DIRECTORY}/sqisign
RUN cd ${DIRECTORY}/sqisign && git checkout ${SQISIGN_COMMIT}
# Obtain Mayo
RUN git clone https://github.com/PQCMayo/MAYO-C ${DIRECTORY}/mayo
RUN cd ${DIRECTORY}/mayo && git checkout ${MAYO_COMMIT}

RUN mkdir -p /usr/lib/patad-testbed && mkdir -p /usr/include/patad-testbed

ADD buildscripts/build-falcon.sh ${DIRECTORY}/build-falcon.sh
ADD buildscripts/build-sqisign.sh ${DIRECTORY}/build-sqisign.sh
ADD buildscripts/build-mayo.sh ${DIRECTORY}/build-mayo.sh
# Now build PQClean: compile Falcon-512
RUN cd ${DIRECTORY} && ./build-falcon.sh
# Now build SQIsign-1
RUN cd ${DIRECTORY} && ./build-sqisign.sh
# Now build Mayo-2
RUN cd ${DIRECTORY} && ./build-mayo.sh

# Now that both Falcon and sqisign are compiled, lets compile the patched PowerDNS version
RUN cd ${DIRECTORY}/pdns/pdns/recursordist && autoreconf -vi
RUN cd ${DIRECTORY}/pdns/pdns/recursordist && \
    ./configure \
      --with-falcon \
      --with-mayo \
      --with-sqisign \
      --sysconfdir=/var/lib/powerdns

RUN cd ${DIRECTORY}/pdns/pdns/recursordist && make -j $(nproc)
RUN cd ${DIRECTORY}/pdns/pdns/recursordist && make install DESTDIR=/build/artifacts


# building the production image
FROM debian:12-slim as pdnsresolverimage

# Install dependencies
RUN apt-get update && apt-get -y dist-upgrade && apt-get clean
RUN apt-get install -y --no-install-recommends python3-jinja2 sqlite3 tini libcap2-bin libssl3 luajit2 libboost-context-dev libboost-filesystem-dev libcurl4 libsodium-dev libgmp10 && apt-get clean

# Copy over relevant powerdns files from build stage, and 'install' them
COPY --from=build /build/artifacts /build/

RUN ln -s /build/usr/local/bin/* /usr/local/bin/
RUN ln -s /build/usr/local/sbin/*  /usr/local/sbin/

# Expose port that powerdns is configured to run on
# This can always be changed later.
EXPOSE 53/tcp
EXPOSE 53/udp

ENTRYPOINT ["pdns_recursor", "--daemon=no"]
