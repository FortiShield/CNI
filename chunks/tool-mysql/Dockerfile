FROM debian:stretch-slim

ARG BUILD_DIR=/tmp/build
ARG MYSQL_VERSION="8.0.19"

RUN buildDeps=' \
  build-essential \
  ca-certificates \
  cmake \
  curl \
  file \
  gcc \
  libncurses5-dev \
  libssl-dev \
  make \
  pkg-config' && \
  apt-get update && \
  apt-get install -y --no-install-recommends $buildDeps && \
  mkdir ${BUILD_DIR} && \
  curl -fsSL https://dev.mysql.com/get/Downloads/MySQL-${MYSQL_VERSION%.*}/mysql-${MYSQL_VERSION}.tar.gz \
  | tar -xz -C ${BUILD_DIR} && \
  cd ${BUILD_DIR}/mysql-${MYSQL_VERSION} && \
  cmake . -DCMAKE_INSTALL_PREFIX=/usr/local/mysql && make && \
  make install && \
  ln -s /usr/local/mysql/bin/mysql /usr/local/bin/mysql && \
  apt-get purge -y $buildDeps && \
  rm -rf /var/lib/apt/lists/* && \
  rm -rf ${BUILD_DIR}

CMD [ "mysql" ]
