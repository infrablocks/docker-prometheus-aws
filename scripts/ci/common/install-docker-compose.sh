#!/usr/bin/env bash

set -euo pipefail

# Pinned + checksum-verified BEFORE install: this runs as root (sudo) on
# runners that later hold secrets; the checksum is from the release's own
# .sha256 asset. Verify in a scratch path so a failed check never leaves an
# unverified binary at the final location. Bumping the pin is a deliberate
# fleet-wide change, not per-repo drift.
if ! command -v docker-compose >/dev/null 2>&1; then
  curl -fsSL \
    "https://github.com/docker/compose/releases/download/v5.3.1/docker-compose-linux-x86_64" \
    -o /tmp/docker-compose
  echo "f9ebc6ebdb19d769b793c245a736caaeb198c62587f13b25c660c13b4987f959  /tmp/docker-compose" \
    | sha256sum -c -
  sudo install -m 0755 /tmp/docker-compose /usr/local/bin/docker-compose
fi
