FROM debian:stretch-slim

ARG BUILD_DIR=/tmp/build
ARG RUST_VERSION="1.42.0"

RUN buildDeps=' \
  build-essential \
  ca-certificates \
  curl \
  file \
  gcc \
  make \
  pkg-config' && \
  apt-get update && \
  apt-get install -y --no-install-recommends $buildDeps && \
  mkdir ${BUILD_DIR} && \
  curl -fsSL https://static.rust-lang.org/rustup/archive/${RUST_VERSION}/x86_64-unknown-linux-gnu/rustup-init \
  -o ${BUILD_DIR}/rustup-init && \
  chmod +x ${BUILD_DIR}/rustup-init && \
  ${BUILD_DIR}/rustup-init -y --default-toolchain ${RUST_VERSION} && \
  rm -rf ${BUILD_DIR} && \
  apt-get purge -y $buildDeps && \
  rm -rf /var/lib/apt/lists/*

CMD [ "rustc" ]
