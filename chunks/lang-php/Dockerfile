FROM debian:stretch-slim

ARG BUILD_DIR=/tmp/build
ARG PHP_VERSION="7.4.3"

RUN buildDeps=' \
  build-essential \
  ca-certificates \
  curl \
  file \
  gcc \
  libxml2-dev \
  libssl-dev \
  make \
  pkg-config \
  zlib1g-dev' && \
  apt-get update && \
  apt-get install -y --no-install-recommends $buildDeps && \
  mkdir ${BUILD_DIR} && \
  curl -fsSL https://www.php.net/distributions/php-${PHP_VERSION}.tar.gz \
  | tar -xz -C ${BUILD_DIR} && \
  cd ${BUILD_DIR}/php-${PHP_VERSION} && \
  ./configure --enable-shared --with-openssl && make && \
  make install && \
  apt-get purge -y $buildDeps && \
  rm -rf /var/lib/apt/lists/* && \
  rm -rf ${BUILD_DIR}

CMD [ "php" ]
