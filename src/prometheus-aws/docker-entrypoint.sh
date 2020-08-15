#!/bin/bash

[ "$TRACE" = "yes" ] && set -x
set -e

storage_tsdb_path="${PROMETHEUS_STORAGE_TSDB_PATH:-/var/lib/prometheus}"
storage_tsdb_retention_time="${PROMETHEUS_STORAGE_TSDB_RETENTION_TIME:-30d}"

additional_options=()

if [[ -n "${PROMETHEUS_WEB_EXTERNAL_URL}" ]]; then
  web_external_url="${PROMETHEUS_WEB_EXTERNAL_URL}"
  web_external_url_option="--web.external-url=${web_external_url}"

  additional_options+=("${web_external_url_option}")
fi

if [[ "${PROMETHEUS_WEB_ENABLE_ADMIN_API}" = "true" ]]; then
  web_enable_admin_api_option="--web.enable-admin-api"

  additional_options+=("${web_enable_admin_api_option}")
fi

if [[ "${PROMETHEUS_WEB_ENABLE_LIFECYCLE}" = "true" ]]; then
  web_enable_lifecycle_option="--web.enable-lifecycle"

  additional_options+=("${web_enable_lifecycle_option}")
fi

echo "Running prometheus."
exec /opt/prometheus/prometheus \
    --config.file="/opt/prometheus/prometheus.yml" \
    \
    --storage.tsdb.path="${storage_tsdb_path}" \
    --storage.tsdb.retention.time="${storage_tsdb_retention_time}" \
    --storage.tsdb.no-lockfile \
    \
    --web.console.libraries="/opt/prometheus/console_libraries" \
    --web.console.templates="/opt/prometheus/consoles" \
    \
    "${additional_options[@]}"
