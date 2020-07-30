#!/usr/bin/env bash

[ -n "$DEBUG" ] && set -x
set -e
set -o pipefail

apk --update add \
    curl

curl -L \
    https://github.com/docker/compose/releases/download/1.25.3/docker-compose-`uname -s`-`uname -m` \
    > /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
