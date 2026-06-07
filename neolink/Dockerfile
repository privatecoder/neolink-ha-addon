ARG BUILD_FROM
FROM ${BUILD_FROM}

# bashio (options + MQTT service API) and jq (config generation)
ARG BASHIO_VERSION=v0.16.2
RUN apt-get update \
 && apt-get install -y --no-install-recommends jq curl bash ca-certificates tar \
 && apt-get clean && rm -rf /var/lib/apt/lists/* \
 && mkdir -p /usr/lib/bashio \
 && curl -fL -s "https://github.com/hassio-addons/bashio/archive/refs/tags/${BASHIO_VERSION}.tar.gz" \
      | tar -xzf - --strip-components=1 -C /usr/lib/bashio \
 && ln -sf /usr/lib/bashio/lib/bashio.sh /usr/bin/bashio

COPY gen-config.sh /usr/bin/neolink-gen-config
COPY run.sh /run.sh
RUN chmod a+x /usr/bin/neolink-gen-config /run.sh

CMD [ "/run.sh" ]
