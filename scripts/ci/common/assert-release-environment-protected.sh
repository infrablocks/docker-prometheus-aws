#!/usr/bin/env bash

set -euo pipefail

# The environment gate is fail-open: if pipeline:prepare never ran, GitHub
# auto-creates 'release' with NO protection rules and the gate job proceeds
# unapproved. Fail loudly instead of releasing ungated — parity with
# CircleCI's hold, which lived in pipeline config and could never silently
# vanish. GH_TOKEN is supplied by the calling workflow step.
count=$(gh api \
  "repos/${GITHUB_REPOSITORY}/environments/release" \
  --jq '.protection_rules | length')
if [ "$count" -eq 0 ]; then
  echo "release environment has no protection rules —" \
    "run ./go pipeline:prepare" >&2
  exit 1
fi
