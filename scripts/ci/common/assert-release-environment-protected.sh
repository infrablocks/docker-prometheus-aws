#!/usr/bin/env bash

set -euo pipefail

# The environment gate is fail-open: on first reference GitHub auto-creates
# the 'release' environment with NO protection rules, so if pipeline:prepare
# never ran the release job proceeds unapproved. Fail closed instead of
# releasing ungated — a missing approver stops the release rather than
# silently waving it through. Count required_reviewers specifically: a
# wait_timer or branch policy is also a protection rule but gates nothing on
# a human. GH_TOKEN is supplied by the calling workflow step.
count=$(gh api \
  "repos/${GITHUB_REPOSITORY}/environments/release" \
  --jq '[.protection_rules[] | select(.type == "required_reviewers")] | length')
if [ "$count" -eq 0 ]; then
  echo "release environment has no required-reviewers rule —" \
    "run ./go pipeline:prepare" >&2
  exit 1
fi
