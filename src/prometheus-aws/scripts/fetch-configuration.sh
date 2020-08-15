#!/bin/bash

[ "$TRACE" = "yes" ] && set -x
set -e

if [[ -n "${PROMETHEUS_CONFIGURATION_FILE_OBJECT_PATH}" ]]; then
  echo "Fetching prometheus configuration file."
  fetch_file_from_s3 \
    "${AWS_S3_BUCKET_REGION}" \
    "${PROMETHEUS_CONFIGURATION_FILE_OBJECT_PATH}" \
    /opt/prometheus/prometheus.yml
else
  var_name="PROMETHEUS_CONFIGURATION_FILE_OBJECT_PATH"
  echo "No ${var_name} provided. Using default configuration."
fi

if [[ -n "${PROMETHEUS_RULE_FILE_OBJECT_PATHS}" ]]; then
  echo "Fetching prometheus rule files."
  for object_path in ${PROMETHEUS_RULE_FILE_OBJECT_PATHS//,/ }; do
    fetch_file_from_s3 \
    "${AWS_S3_BUCKET_REGION}" \
    "${object_path}" \
    /opt/prometheus/rules/
  done
else
  var_name="PROMETHEUS_RULE_FILE_OBJECT_PATHS"
  echo "No ${var_name} provided. Continuing."
fi

