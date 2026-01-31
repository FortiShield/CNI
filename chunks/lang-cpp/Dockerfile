FROM debian:stretch-slim

ARG BUILD_DIR=/tmp/build
ARG GCC_VERSION="9.3.0"

RUN buildDeps=' \
  build-essential \
  ca-certificates \
  curl \
  file \
  gcc \
  g++ \
  make \
  zlib1g-dev' && \
  apt-get update && \
  apt-get install -y --no-install-recommends $buildDeps && \
  mkdir ${BUILD_DIR} && \
  curl -fsSL https://ftp.gnu.org/gnu/gcc/gcc-${GCC_VERSION}/gcc-${GCC_VERSION}.tar.gz \
  | tar -xz -C ${BUILD_DIR} && \
  cd ${BUILD_DIR}/gcc-${GCC_VERSION} && \
  ./contrib/download_prerequisites && \
  ./configure --enable-languages=c,c++ --disable-multilib && make && \
  make install && \
  apt-get purge -y $buildDeps && \
  rm -rf /var/lib/apt/lists/* && \
  rm -rf ${BUILD_DIR}

CMD [ "gcc" ]
