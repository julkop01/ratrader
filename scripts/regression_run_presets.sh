#!/usr/bin/env bash
set -euo pipefail

PYTHON=${PYTHON:-python3}
SCRIPTDIR=$(dirname "$0")
ROOT=$(cd "$SCRIPTDIR/.." && pwd)

echo "Running preset v1 validation..."

Run the preset validator inside Python via a here-document to avoid shell parsing issues.
$PYTHON - <<'PY'
import sys
from pathlib import Path
repo_root = Path("$ROOT")
presets_dir = repo_root / "artifacts" / "presets" / "v1"
if not presets_dir.exists():
sys.exit(f"Presets directory not found: {presets_dir}")

Insert the backtester path so we can import the validator module
sys.path.insert(0, str(repo_root))
try:
from backtester.regression_checks import preset_v1_validation_test as validator
validator.run_all(str(presets_dir))
print("Preset validation passed")
except Exception as e:
print("Preset validation failed:", e)
raise
PY
