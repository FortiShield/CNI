FROM debian:stretch-slim

ARG BUILD_DIR=/tmp/build
ARG BUN_VERSION="0.6.3"

RUN buildDeps=' \
  build-essential \
  ca-certificates \
  curl \
  file \
  make \
  unzip' && \
  apt-get update && \
  apt-get install -y --no-install-recommends $buildDeps && \
  mkdir ${BUILD_DIR} && \
  curl -fsSL https://github.com/oven-sh/bun/releases/download/bun-v${BUN_VERSION}/bun-linux-x64.zip \
  -o ${BUILD_DIR}/bun.zip && \
  unzip ${BUILD_DIR}/bun.zip -d ${BUILD_DIR} && \
  mv ${BUILD_DIR}/bun-linux-x64/bun /usr/local/bin/bun && \
  chmod +x /usr/local/bin/bun && \
  apt-get purge -y $buildDeps && \
  rm -rf /var/lib/apt/lists/* && \
  rm -rf ${BUILD_DIR}

CMD [ "bun" ]
