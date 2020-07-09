#!/bin/bash

[ "$TRACE" = "yes" ] && set -x
set -e

echo "Running prometheus."
exec /opt/prometheus/prometheus \
    --config.file /opt/prometheus/prometheus.yaml \
    --web.console.libraries=/opt/prometheus/console_libraries \
    --web.console.templates=/opt/prometheus/consoles \
    --web.enable-admin-api
