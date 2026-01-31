FROM debian:stretch-slim

ARG BUILD_DIR=/tmp/build
ARG DOCKER_VERSION="19.03.8"

RUN buildDeps=' \
  build-essential \
  ca-certificates \
  curl \
  file \
  make \
  wget' && \
  apt-get update && \
  apt-get install -y --no-install-recommends $buildDeps && \
  mkdir ${BUILD_DIR} && \
  curl -fsSL https://download.docker.com/linux/static/stable/x86_64/docker-${DOCKER_VERSION}.tgz \
  | tar -xz -C ${BUILD_DIR} && \
  mv ${BUILD_DIR}/docker/docker /usr/local/bin/docker && \
  chmod +x /usr/local/bin/docker && \
  apt-get purge -y $buildDeps && \
  rm -rf /var/lib/apt/lists/* && \
  rm -rf ${BUILD_DIR}

CMD [ "docker" ]
