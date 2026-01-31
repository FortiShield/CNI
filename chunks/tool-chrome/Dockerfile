FROM debian:stretch-slim

ARG BUILD_DIR=/tmp/build
ARG CHROME_VERSION="81.0.4044.113"

RUN buildDeps=' \
  build-essential \
  ca-certificates \
  curl \
  file \
  make \
  wget \
  unzip' && \
  apt-get update && \
  apt-get install -y --no-install-recommends $buildDeps libgtk-3-0 libxss1 libasound2 && \
  mkdir ${BUILD_DIR} && \
  curl -fsSL https://dl.google.com/linux/chrome/deb/pool/main/g/google-chrome-stable/google-chrome-stable_${CHROME_VERSION}-1_amd64.deb \
  -o ${BUILD_DIR}/chrome.deb && \
  dpkg -i ${BUILD_DIR}/chrome.deb || apt-get install -y -f && \
  apt-get purge -y $buildDeps && \
  rm -rf /var/lib/apt/lists/* && \
  rm -rf ${BUILD_DIR}

CMD [ "google-chrome" ]
