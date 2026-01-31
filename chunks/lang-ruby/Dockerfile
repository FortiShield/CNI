FROM debian:stretch-slim

ARG BUILD_DIR=/tmp/build
ARG RUBY_VERSION="2.7.0"

RUN buildDeps=' \
  build-essential \
  ca-certificates \
  curl \
  file \
  gcc \
  libssl-dev \
  make \
  zlib1g-dev' && \
  apt-get update && \
  apt-get install -y --no-install-recommends $buildDeps && \
  mkdir ${BUILD_DIR} && \
  curl -fsSL https://cache.ruby-lang.org/pub/ruby/${RUBY_VERSION%.*}/ruby-${RUBY_VERSION}.tar.gz \
  | tar -xz -C ${BUILD_DIR} && \
  cd ${BUILD_DIR}/ruby-${RUBY_VERSION} && \
  ./configure --enable-shared && make && \
  make install && \
  apt-get purge -y $buildDeps && \
  rm -rf /var/lib/apt/lists/* && \
  rm -rf ${BUILD_DIR}

CMD [ "ruby" ]
