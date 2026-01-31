FROM debian:stretch-slim

ARG BUILD_DIR=/tmp/build
ARG NGINX_VERSION="1.17.10"

RUN buildDeps=' \
  build-essential \
  ca-certificates \
  curl \
  file \
  gcc \
  libpcre3-dev \
  libssl-dev \
  make \
  zlib1g-dev' && \
  apt-get update && \
  apt-get install -y --no-install-recommends $buildDeps && \
  mkdir ${BUILD_DIR} && \
  curl -fsSL https://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz \
  | tar -xz -C ${BUILD_DIR} && \
  cd ${BUILD_DIR}/nginx-${NGINX_VERSION} && \
  ./configure --prefix=/usr/local/nginx && make && \
  make install && \
  ln -s /usr/local/nginx/sbin/nginx /usr/local/bin/nginx && \
  apt-get purge -y $buildDeps && \
  rm -rf /var/lib/apt/lists/* && \
  rm -rf ${BUILD_DIR}

CMD [ "nginx" ]
