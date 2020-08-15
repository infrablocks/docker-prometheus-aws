FROM infrablocks/alpine-aws-s3-config:0.18.0

ENV PROMETHEUS_VERSION 2.20.0

RUN cd /tmp \
    && curl \
        -L "https://github.com/prometheus/prometheus/releases/download/v${PROMETHEUS_VERSION}/prometheus-${PROMETHEUS_VERSION}.linux-amd64.tar.gz" \
        -o "prometheus-${PROMETHEUS_VERSION}.linux-amd64.tar.gz" \
    && tar -xvf "prometheus-${PROMETHEUS_VERSION}.linux-amd64.tar.gz" \
    && mkdir -p /opt/prometheus \
    && cp -R "prometheus-${PROMETHEUS_VERSION}.linux-amd64"/* /opt/prometheus \
    && rm "prometheus-${PROMETHEUS_VERSION}.linux-amd64.tar.gz" \
    && rm -rf "prometheus-${PROMETHEUS_VERSION}.linux-amd64" \
    && cd /

RUN mkdir /opt/prometheus/rules

COPY docker-entrypoint.sh /opt/prometheus/docker-entrypoint.sh
COPY scripts/fetch-configuration.sh /opt/prometheus/scripts/fetch-configuration.sh

RUN ["chmod", "+x", "/opt/prometheus/docker-entrypoint.sh"]
RUN ["chmod", "+x", "/opt/prometheus/scripts/fetch-configuration.sh"]

ENV STARTUP_SCRIPT_PATH=/opt/prometheus/docker-entrypoint.sh
ENV FETCH_SECRETS_FILES_SCRIPT_PATH=/opt/prometheus/scripts/fetch-configuration.sh
