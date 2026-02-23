#!/usr/bin/env bash
# session-start-reset.sh — wrapper for SessionStart events that must reset metrics.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"

exec /bin/bash "${SCRIPT_DIR}/session-start.sh" --reset-metrics
