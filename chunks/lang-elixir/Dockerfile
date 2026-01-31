FROM debian:stretch-slim

ARG BUILD_DIR=/tmp/build
ARG ELIXIR_VERSION="1.9.4"
ARG OTP_VERSION="22.2"

RUN buildDeps=' \
  build-essential \
  ca-certificates \
  curl \
  file \
  gcc \
  libssl-dev \
  make \
  wget \
  zlib1g-dev' && \
  apt-get update && \
  apt-get install -y --no-install-recommends $buildDeps && \
  mkdir ${BUILD_DIR} && \
  curl -fsSL https://github.com/erlang/otp/archive/OTP-${OTP_VERSION}.tar.gz \
  | tar -xz -C ${BUILD_DIR} && \
  cd ${BUILD_DIR}/otp-OTP-${OTP_VERSION} && \
  ./configure --enable-dirty-schedulers && make && \
  make install && \
  curl -fsSL https://github.com/elixir-lang/elixir/archive/v${ELIXIR_VERSION}.tar.gz \
  | tar -xz -C ${BUILD_DIR} && \
  cd ${BUILD_DIR}/elixir-${ELIXIR_VERSION} && \
  make install && \
  apt-get purge -y $buildDeps && \
  rm -rf /var/lib/apt/lists/* && \
  rm -rf ${BUILD_DIR}

CMD [ "iex" ]
