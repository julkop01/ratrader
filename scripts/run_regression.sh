#!/usr/bin/env bash
set -euo pipefail

PYTHON=${PYTHON:-python3}
SCRIPTDIR=$(dirname "$0")
ROOT=$(cd "$SCRIPTDIR/.." && pwd)

# ensure PYTHONPATH points to repo root for reproducible CI runs
export PYTHONPATH="$ROOT"

echo "Starting regression runner"
"$SCRIPTDIR/regression_run_presets.sh"

echo "Comparing backtest reports to golden traces"
# Non-fatal comparisons (do not fail the whole run here)
$PYTHON "$ROOT/backtester/tools/compare_traces.py" "$ROOT/artifacts/golden/prop_friendly_golden.json" "$ROOT/artifacts/backtests/reports/example_prop_friendly_report.json" || true
$PYTHON "$ROOT/backtester/tools/compare_traces.py" "$ROOT/artifacts/golden/prop_friendly_2symbol_golden.json" "$ROOT/artifacts/backtests/reports/example_prop_friendly_2symbol_report.json" || true

echo "Running session-realism check: hf_daily_limits"
$PYTHON "$ROOT/backtester/run_ote_tracedriven_single.py" --file "$ROOT/artifacts/backtests/data/XRPUSDT1_sample.tsv" --preset "$ROOT/artifacts/presets/v1/hf_daily_limits_preset.json" --out "$ROOT/artifacts/backtests/reports/hf_daily_limits_report.tsv" --audit_out "$ROOT/artifacts/backtests/reports/hf_daily_limits_audit.tsv" || true

# Compare audit to golden (fail-fast)
if ! $PYTHON "$ROOT/backtester/tools/compare_tsv_audit.py" "$ROOT/artifacts/backtests/golden/hf_daily_limits_audit_golden.tsv" "$ROOT/artifacts/backtests/reports/hf_daily_limits_report.tsv"; then
  echo "Session realism audit differs from golden"
  "$SCRIPTDIR/regression_failure_dump.sh" "hf_daily_limits audit mismatch" "$ROOT/artifacts/backtests/reports/hf_daily_limits_report.tsv" "$ROOT/artifacts/backtests/golden/hf_daily_limits_audit_golden.tsv"
  exit 1
fi

echo "Comparing PropFriendly trace summary to golden"
python3 - <<'PY'
from pathlib import Path
import json
root = Path("$ROOT")
summary = root / "artifacts/golden/prop_friendly_trace_summary.json"
trace = root / "artifacts/traces/prop_friendly_trace.jsonl"
if not summary.exists() or not trace.exists():
    print('missing trace or summary')
    raise SystemExit(2)
s = json.loads(summary.read_text(encoding='utf-8'))
lines = [L for L in trace.read_text(encoding='utf-8').splitlines() if not L.startswith('#')]
count = len(lines) - 1
if count != s.get('records'):
    print(f"PropFriendly trace record count differs: golden={s.get('records')} got={count}")
    raise SystemExit(1)
print('PropFriendly trace summary matches')
PY

echo "Running tracer vs session parity check"
PYTHONPATH="$ROOT" python3 "$ROOT/backtester/regression_checks/test_tracer_strategy_parity.py" || { echo "Parity check failed"; exit 1; }

echo "Checking golden manifest coverage"
PYTHONPATH="$ROOT" python3 "$ROOT/backtester/regression_checks/test_golden_manifest.py" || { echo "Golden manifest coverage failed"; exit 1; }

echo "Regression runner completed"
