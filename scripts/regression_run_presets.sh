#!/usr/bin/env bash
set -euo pipefail
PYTHON=${PYTHON:-python3}
SCRIPTDIR=$(dirname "$0")
ROOT=$(cd "$SCRIPTDIR/.." && pwd)

echo "Running preset v1 validation..."

Run the preset validator from the code tree (regression checks)
$PYTHON "$ROOT/backtester/regression_checks/preset_v1_validation_test.py" || {
echo "Preset validation failed"
exit 1
}
echo "Preset validation passed"
