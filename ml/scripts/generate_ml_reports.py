"""Generate markdown performance reports from JSON training outputs."""

from __future__ import annotations

import json
from pathlib import Path

from config import LSTM_AUC_PROPOSAL, PROPHET_MAPE_PROPOSAL, REPORTS


def _load(name: str) -> dict | None:
    path = REPORTS / name
    if not path.exists():
        return None
    return json.loads(path.read_text(encoding="utf-8"))


def prophet_report(data: dict) -> str:
    by_type = data.get("by_station_type", {})
    type_lines = "\n".join(
        f"| {stype} | {stats['count']} | {stats.get('avg_val_mape', '-')} | {stats.get('avg_test_mape', '-')} |"
        for stype, stats in sorted(by_type.items())
    )
    split = data.get("temporal_split", {})
    return f"""# Prophet Demand Forecasting — Performance Report

**FuelSense LK** | Full training pipeline

## Summary

| Metric | Value |
|--------|-------|
| Stations trained | {data.get('stations_trained', 0)} / {data.get('stations_requested', 0)} |
| Fuel type | {data.get('fuel_type', 'petrol_92')} |
| Granularity | {data.get('granularity', 'hourly')} |
| Avg validation MAPE | **{data.get('avg_val_mape')}%** |
| Avg test MAPE | **{data.get('avg_test_mape')}%** |
| Target test MAPE | <= {PROPHET_MAPE_PROPOSAL * 100}% |
| Meets target | {'Yes' if data.get('meets_target_test') else 'No'} |
| Training time | {data.get('train_seconds', '-')}s |

## Temporal Split

| Split | Period |
|-------|--------|
| Train | {split.get('train', 'Jan-Sep')} |
| Validation | {split.get('val', 'Oct-Nov')} |
| Test | {split.get('test', 'Dec')} |

## MAPE by Station Type

| Station type | Stations | Val MAPE | Test MAPE |
|--------------|----------|----------|-----------|
{type_lines or '| — | — | — | — |'}

## Methodology

- One Prophet model per station
- Regressors: {', '.join(data.get('regressors', []))}
- Stan MCMC backend (no batch size / epochs)
- Strict temporal split per `ml/docs/data_bias_and_leakage_controls.md`
"""


def lstm_horizon_report(data: dict) -> str:
    hp = data.get("hyperparameters", {})
    arch = data.get("architecture", {})
    val_m = data.get("validation", {})
    test_m = data.get("test", {})
    wc = data.get("window_counts", {})

    return f"""# LSTM Depletion Risk — {data.get('horizon_hours', 12)}h Horizon

## Architecture

| Component | Value |
|-----------|-------|
| Model | Stacked LSTM |
| Layers | {' -> '.join(arch.get('layers', []))} |
| Lookback | {arch.get('lookback_hours', 12)} hours |
| Features / step | {', '.join(arch.get('features', []))} |

## Hyperparameters

| Parameter | Value |
|-----------|-------|
| Max epochs | {hp.get('epochs_max')} |
| Epochs trained | {hp.get('epochs_trained')} |
| Best epoch (val AUC) | {hp.get('best_epoch_val_auc')} |
| Batch size | {hp.get('batch_size')} |
| Learning rate | {hp.get('learning_rate')} |
| Dropout | {hp.get('dropout')} |
| Early stopping patience | {hp.get('early_stopping_patience')} |
| Classification threshold | {hp.get('classification_threshold')} |

## Dataset Windows

| Split | Windows | Positive rate |
|-------|---------|-----------------|
| Train | {wc.get('train', '-'):,} | (see training log) |
| Validation | {wc.get('val', '-'):,} | {val_m.get('positive_rate', '-')} |
| Test | {wc.get('test', '-'):,} | {test_m.get('positive_rate', '-')} |

## Validation Metrics

| Metric | Value |
|--------|-------|
| AUC | **{val_m.get('auc')}** |
| Accuracy | {val_m.get('accuracy')} |
| Precision | {val_m.get('precision')} |
| Recall | {val_m.get('recall')} |
| F1 | {val_m.get('f1')} |
| Confusion matrix | TN={val_m.get('confusion_matrix', {}).get('tn')} FP={val_m.get('confusion_matrix', {}).get('fp')} FN={val_m.get('confusion_matrix', {}).get('fn')} TP={val_m.get('confusion_matrix', {}).get('tp')} |

## Test Metrics (held-out December)

| Metric | Value |
|--------|-------|
| AUC | **{test_m.get('auc')}** |
| Accuracy | {test_m.get('accuracy')} |
| Precision | {test_m.get('precision')} |
| Recall | {test_m.get('recall')} |
| F1 | {test_m.get('f1')} |
| Meets AUC target (>={LSTM_AUC_PROPOSAL}) | {'Yes' if data.get('meets_target_test_auc') else 'No'} |

ROC charts: `reports/charts/lstm_roc_val_{data.get('horizon_hours')}h.png`, `lstm_roc_test_{data.get('horizon_hours')}h.png`
"""


def lstm_report(combined: dict | None, h12: dict | None) -> str:
    primary = h12 or combined
    if not primary:
        return "# LSTM report not found\n"
    if "horizons" in primary:
        sections = [lstm_horizon_report(primary["horizons"][h]) for h in sorted(primary["horizons"])]
        header = f"# LSTM Depletion Risk — Full Report\n\nStations: {primary.get('stations_used', '-')}\n\n"
        return header + "\n---\n\n".join(sections)
    return lstm_horizon_report(primary)


def arima_report(prophet: dict | None, arima: dict | None, lstm: dict | None) -> str:
    p_mape = prophet.get("avg_test_mape") if prophet else "—"
    a_mape = arima.get("avg_mape") if arima else "—"
    lstm_auc = (lstm or {}).get("test", {}).get("auc") or (lstm or {}).get("auc")
    return f"""# ARIMA Baseline — Academic Comparison

## Forecast Accuracy (MAPE)

| Model | Test MAPE | Notes |
|-------|-----------|-------|
| Prophet | {p_mape}% | Production forecasting |
| ARIMA(2,1,2) | {a_mape}% | Academic baseline only |

## Depletion Risk (12h)

| Model | Test AUC |
|-------|----------|
| Stacked LSTM | {lstm_auc} |
"""


def main() -> None:
    REPORTS.mkdir(parents=True, exist_ok=True)

    prophet = _load("prophet_performance.json") or _load("prophet_performance_hourly.json")
    arima = _load("arima_baseline.json")
    lstm_combined = _load("lstm_performance.json")
    lstm_12 = _load("lstm_performance_12h.json")

    if prophet:
        (REPORTS / "prophet_performance.md").write_text(prophet_report(prophet), encoding="utf-8")
        print("Wrote prophet_performance.md")
    (REPORTS / "lstm_performance.md").write_text(lstm_report(lstm_combined, lstm_12), encoding="utf-8")
    print("Wrote lstm_performance.md")
    if prophet or arima:
        (REPORTS / "arima_baseline.md").write_text(arima_report(prophet, arima, lstm_12), encoding="utf-8")
        print("Wrote arima_baseline.md")


if __name__ == "__main__":
    main()
