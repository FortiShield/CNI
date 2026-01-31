FROM debian:stretch-slim

ARG BUILD_DIR=/tmp/build
ARG JAVA_VERSION="11"

RUN buildDeps=' \
  build-essential \
  ca-certificates \
  curl \
  file \
  gcc \
  make \
  wget \
  unzip' && \
  apt-get update && \
  apt-get install -y --no-install-recommends $buildDeps && \
  mkdir ${BUILD_DIR} && \
  curl -fsSL https://download.java.net/java/GA/jdk11/9/GPL/openjdk-${JAVA_VERSION}_linux-x64_bin.tar.gz \
  | tar -xz -C ${BUILD_DIR} && \
  mv ${BUILD_DIR}/jdk-${JAVA_VERSION} /usr/local/openjdk-${JAVA_VERSION} && \
  ln -s /usr/local/openjdk-${JAVA_VERSION} /usr/local/java && \
  echo 'export PATH=/usr/local/java/bin:$PATH' >> /etc/profile && \
  echo 'export JAVA_HOME=/usr/local/java' >> /etc/profile && \
  apt-get purge -y $buildDeps && \
  rm -rf /var/lib/apt/lists/* && \
  rm -rf ${BUILD_DIR}

CMD [ "java" ]
