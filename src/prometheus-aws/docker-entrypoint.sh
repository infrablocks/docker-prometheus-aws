#!/bin/bash

[ "$TRACE" = "yes" ] && set -x
set -e

storage_tsdb_path="${PROMETHEUS_STORAGE_TSDB_PATH:-/var/lib/prometheus}"
storage_tsdb_retention_time="${PROMETHEUS_STORAGE_TSDB_RETENTION_TIME:-30d}"

echo "Running prometheus."
exec /opt/prometheus/prometheus \
    --config.file="/opt/prometheus/prometheus.yml" \
    --storage.tsdb.path="${storage_tsdb_path}" \
    --storage.tsdb.retention.time="${storage_tsdb_retention_time}" \
    --web.console.libraries="/opt/prometheus/console_libraries" \
    --web.console.templates="/opt/prometheus/consoles" \
    --web.enable-admin-api
