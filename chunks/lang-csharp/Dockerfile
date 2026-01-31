FROM debian:stretch-slim

ARG BUILD_DIR=/tmp/build
ARG DOTNET_VERSION="3.1.3"

RUN buildDeps=' \
  build-essential \
  ca-certificates \
  curl \
  file \
  gcc \
  make \
  wget' && \
  apt-get update && \
  apt-get install -y --no-install-recommends $buildDeps && \
  mkdir ${BUILD_DIR} && \
  curl -fsSL https://download.visualstudio.microsoft.com/download/pr/8b8b348a-3d9a-4e4a-9b8c-8c8a6d8b8b8b/dotnet-sdk-${DOTNET_VERSION}-linux-x64.tar.gz \
  -o ${BUILD_DIR}/dotnet-sdk.tar.gz && \
  tar -xzf ${BUILD_DIR}/dotnet-sdk.tar.gz -C /usr/local && \
  ln -s /usr/local/dotnet/dotnet /usr/local/bin/dotnet && \
  apt-get purge -y $buildDeps && \
  rm -rf /var/lib/apt/lists/* && \
  rm -rf ${BUILD_DIR}

CMD [ "dotnet" ]
