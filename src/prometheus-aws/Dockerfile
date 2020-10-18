FROM infrablocks/alpine-aws-s3-config:0.21.0-rc.8

ENV PROMETHEUS_VERSION 2.22.0

RUN apk add --update --no-cache \
    gettext

RUN cd /tmp \
    && curl \
        -L "https://github.com/prometheus/prometheus/releases/download/v${PROMETHEUS_VERSION}/prometheus-${PROMETHEUS_VERSION}.linux-amd64.tar.gz" \
        -o "prometheus-${PROMETHEUS_VERSION}.linux-amd64.tar.gz" \
    && tar -xvf "prometheus-${PROMETHEUS_VERSION}.linux-amd64.tar.gz" \
    && mkdir -p /opt/prometheus \
    && cp -R "prometheus-${PROMETHEUS_VERSION}.linux-amd64"/* /opt/prometheus \
    && mkdir -p /opt/prometheus/conf /opt/prometheus/bin \
    && mv /opt/prometheus/prometheus /opt/prometheus/bin \
    && mv /opt/prometheus/promtool /opt/prometheus/bin \
    && mv /opt/prometheus/prometheus.yml /opt/prometheus/conf \
    && rm "prometheus-${PROMETHEUS_VERSION}.linux-amd64.tar.gz" \
    && rm -rf "prometheus-${PROMETHEUS_VERSION}.linux-amd64" \
    && cd /

RUN mkdir /opt/prometheus/conf/rules

COPY start.sh /opt/prometheus/bin/start.sh
COPY scripts/fetch-configuration.sh /opt/prometheus/scripts/fetch-configuration.sh

RUN ["chmod", "+x", "/opt/prometheus/bin/start.sh"]
RUN ["chmod", "+x", "/opt/prometheus/scripts/fetch-configuration.sh"]

ENV STARTUP_SCRIPT_PATH=/opt/prometheus/bin/start.sh
ENV FETCH_SECRETS_FILES_SCRIPT_PATH=/opt/prometheus/scripts/fetch-configuration.sh
