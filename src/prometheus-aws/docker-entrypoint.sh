#!/bin/bash

[ "$TRACE" = "yes" ] && set -x
set -e

storage_tsdb_path="${PROMETHEUS_STORAGE_TSDB_PATH:-/var/opt/prometheus}"
storage_tsdb_retention_time="${PROMETHEUS_STORAGE_TSDB_RETENTION_TIME:-30d}"

storage_tsdb_min_block_duration_option=
if [ -n "${PROMETHEUS_STORAGE_TSDB_MINIMUM_BLOCK_DURATION}" ]; then
  duration="${PROMETHEUS_STORAGE_TSDB_MINIMUM_BLOCK_DURATION}"
  storage_tsdb_min_block_duration_option="--storage.tsdb.min-block-duration=${duration}"
fi

storage_tsdb_max_block_duration_option=
if [ -n "${PROMETHEUS_STORAGE_TSDB_MAXIMUM_BLOCK_DURATION}" ]; then
  duration="${PROMETHEUS_STORAGE_TSDB_MAXIMUM_BLOCK_DURATION}"
  storage_tsdb_max_block_duration_option="--storage.tsdb.max-block-duration=${duration}"
fi

web_external_url_option=
if [ -n "${PROMETHEUS_WEB_EXTERNAL_URL}" ]; then
  web_external_url="${PROMETHEUS_WEB_EXTERNAL_URL}"
  web_external_url_option="--web.external-url=${web_external_url}"
fi

web_enable_admin_api_option=
if [[ "${PROMETHEUS_WEB_ADMIN_API_ENABLED}" = "yes" ]]; then
  web_enable_admin_api_option="--web.enable-admin-api"
fi

web_enable_lifecycle_option=
if [[ "${PROMETHEUS_WEB_LIFECYCLE_ENABLED}" = "yes" ]]; then
  web_enable_lifecycle_option="--web.enable-lifecycle"
fi

echo "Running prometheus."
# shellcheck disable=SC2086
exec /opt/prometheus/prometheus \
    --config.file="/opt/prometheus/prometheus.yml" \
    \
    --storage.tsdb.path="${storage_tsdb_path}" \
    --storage.tsdb.retention.time="${storage_tsdb_retention_time}" \
    --storage.tsdb.no-lockfile \
    ${storage_tsdb_min_block_duration_option} \
    ${storage_tsdb_max_block_duration_option} \
    \
    --web.console.libraries="/opt/prometheus/console_libraries" \
    --web.console.templates="/opt/prometheus/consoles" \
    ${web_external_url_option} \
    ${web_enable_admin_api_option} \
    ${web_enable_lifecycle_option} \
    \
    --log.format="json" \
