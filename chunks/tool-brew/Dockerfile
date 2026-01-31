FROM debian:stretch-slim

ARG BUILD_DIR=/tmp/build

RUN buildDeps=' \
  build-essential \
  ca-certificates \
  curl \
  file \
  git \
  make \
  ruby' && \
  apt-get update && \
  apt-get install -y --no-install-recommends $buildDeps && \
  mkdir ${BUILD_DIR} && \
  git clone https://github.com/Homebrew/brew ${BUILD_DIR}/brew && \
  mv ${BUILD_DIR}/brew /usr/local/homebrew && \
  ln -s /usr/local/homebrew/bin/brew /usr/local/bin/brew && \
  apt-get purge -y $buildDeps && \
  rm -rf /var/lib/apt/lists/* && \
  rm -rf ${BUILD_DIR}

CMD [ "brew" ]
