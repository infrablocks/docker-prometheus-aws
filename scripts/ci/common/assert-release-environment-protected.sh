#!/usr/bin/env bash

set -euo pipefail

# The environment gate is fail-open: on first reference GitHub auto-creates
# the 'release' environment with NO protection rules, so if pipeline:prepare
# never ran the gate job proceeds unapproved. Fail closed instead of
# releasing ungated — a missing protection rule stops the release rather than
# silently waving it through. GH_TOKEN is supplied by the calling workflow
# step.
count=$(gh api \
  "repos/${GITHUB_REPOSITORY}/environments/release" \
  --jq '.protection_rules | length')
if [ "$count" -eq 0 ]; then
  echo "release environment has no protection rules —" \
    "run ./go pipeline:prepare" >&2
  exit 1
fi
