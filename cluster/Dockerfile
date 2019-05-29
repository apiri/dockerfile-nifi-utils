FROM apache/nifi:1.9.2
MAINTAINER Apache NiFi <dev@nifi.apache.org>

ENV NIFI_BASE_DIR /opt/nifi
ENV NIFI_HOME ${NIFI_BASE_DIR}/nifi-current

# Download, validate, and expand Apache NiFi binary.
USER root
RUN apt-get update \
  && apt-get install jq

RUN wget https://github.com/outbrain/zookeepercli/releases/download/v1.0.10/zookeepercli_1.0.10_amd64.deb \
	&& dpkg -i zookeepercli_1.0.10_amd64.deb
ADD    ./sh/ /opt/nifi/sh
RUN chown -R nifi:nifi /opt/nifi

USER nifi

# Startup NiFi
ENTRYPOINT ${NIFI_BASE_DIR}/sh/start.sh
