"""Shared ML utilities — splits, metrics, reproducibility."""

from __future__ import annotations

import json
import random
from pathlib import Path
from typing import Any

import numpy as np
import pandas as pd
from sklearn.metrics import (
    accuracy_score,
    confusion_matrix,
    f1_score,
    precision_score,
    recall_score,
    roc_auc_score,
    roc_curve,
)

from config import (
    DATA_SPLITS,
    LSTM_FEATURE_COLUMNS,
    LSTM_LOOKBACK_HOURS,
    RANDOM_SEED,
)


def set_seed(seed: int = RANDOM_SEED) -> None:
    random.seed(seed)
    np.random.seed(seed)
    try:
        import tensorflow as tf

        tf.random.set_seed(seed)
    except ImportError:
        pass


def mape(y_true: np.ndarray, y_pred: np.ndarray) -> float:
    mask = y_true > 0
    if not mask.any():
        return float("nan")
    return float(np.mean(np.abs((y_true[mask] - y_pred[mask]) / y_true[mask])) * 100)


def load_splits(
    fuel_type: str | None = None,
    extra_columns: tuple[str, ...] = (),
) -> tuple[pd.DataFrame, pd.DataFrame, pd.DataFrame]:
    base_cols = {
        "station_id",
        "station_type",
        "timestamp",
        "fuel_type",
        "demand_litres",
        "stock_litres",
        "stock_percentage",
        *LSTM_FEATURE_COLUMNS,
        "run_out_6h",
        "run_out_12h",
        "run_out_24h",
        *extra_columns,
    }
    out = []
    for name in ("train", "val", "test"):
        path = DATA_SPLITS / f"{name}.csv"
        header = pd.read_csv(path, nrows=0).columns.tolist()
        usecols = [c for c in base_cols if c in header]
        chunks = []
        for chunk in pd.read_csv(path, usecols=usecols, parse_dates=["timestamp"], chunksize=500_000):
            if fuel_type:
                chunk = chunk[chunk["fuel_type"] == fuel_type]
            if len(chunk):
                chunks.append(chunk)
        out.append(pd.concat(chunks, ignore_index=True) if chunks else pd.DataFrame(columns=usecols))
    return out[0], out[1], out[2]


def split_row_counts(train: pd.DataFrame, val: pd.DataFrame, test: pd.DataFrame) -> dict[str, Any]:
    return {
        "train_rows": int(len(train)),
        "val_rows": int(len(val)),
        "test_rows": int(len(test)),
        "train_stations": int(train["station_id"].nunique()),
        "val_stations": int(val["station_id"].nunique()),
        "test_stations": int(test["station_id"].nunique()),
        "train_time_min": str(train["timestamp"].min()),
        "train_time_max": str(train["timestamp"].max()),
        "val_time_min": str(val["timestamp"].min()),
        "val_time_max": str(val["timestamp"].max()),
        "test_time_min": str(test["timestamp"].min()),
        "test_time_max": str(test["timestamp"].max()),
    }


def build_lstm_sequences(
    df: pd.DataFrame,
    horizon: int,
    lookback: int = LSTM_LOOKBACK_HOURS,
    feature_columns: tuple[str, ...] = LSTM_FEATURE_COLUMNS,
) -> tuple[np.ndarray, np.ndarray]:
    """Build (samples, lookback, features) windows — causal features only at time t."""
    label_col = f"run_out_{horizon}h"
    df = df.sort_values("timestamp")
    feat = df[list(feature_columns)].to_numpy(dtype=np.float32)
    labels = df[label_col].to_numpy(dtype=np.float32)

    # Normalize hour to [0, 1]
    hour_idx = list(feature_columns).index("hour_of_day")
    feat[:, hour_idx] = feat[:, hour_idx] / 23.0
    # Stock percentage to [0, 1]
    pct_idx = list(feature_columns).index("stock_percentage")
    feat[:, pct_idx] = feat[:, pct_idx] / 100.0

    xs, ys = [], []
    for i in range(lookback, len(df)):
        xs.append(feat[i - lookback : i])
        ys.append(labels[i])
    if not xs:
        return np.empty((0, lookback, len(feature_columns)), dtype=np.float32), np.empty(0)
    return np.stack(xs), np.array(ys, dtype=np.float32)


def stack_station_sequences(
    df: pd.DataFrame,
    station_ids: list[int],
    horizon: int,
    lookback: int = LSTM_LOOKBACK_HOURS,
) -> tuple[np.ndarray, np.ndarray]:
    xs, ys = [], []
    for sid in station_ids:
        sub = df[df["station_id"] == sid]
        if len(sub) < lookback + 1:
            continue
        X, y = build_lstm_sequences(sub, horizon=horizon, lookback=lookback)
        if len(X):
            xs.append(X)
            ys.append(y)
    if not xs:
        return np.empty((0, lookback, len(LSTM_FEATURE_COLUMNS))), np.empty(0)
    return np.vstack(xs), np.concatenate(ys)


def classification_metrics(
    y_true: np.ndarray,
    y_prob: np.ndarray,
    threshold: float = 0.5,
) -> dict[str, Any]:
    y_pred = (y_prob >= threshold).astype(int)
    metrics: dict[str, Any] = {
        "threshold": threshold,
        "samples": int(len(y_true)),
        "positive_rate": round(float(np.mean(y_true)), 4),
        "predicted_positive_rate": round(float(np.mean(y_pred)), 4),
        "accuracy": round(float(accuracy_score(y_true, y_pred)), 4),
        "precision": round(float(precision_score(y_true, y_pred, zero_division=0)), 4),
        "recall": round(float(recall_score(y_true, y_pred, zero_division=0)), 4),
        "f1": round(float(f1_score(y_true, y_pred, zero_division=0)), 4),
    }
    if len(np.unique(y_true)) > 1:
        metrics["auc"] = round(float(roc_auc_score(y_true, y_prob)), 4)
    else:
        metrics["auc"] = None
    tn, fp, fn, tp = confusion_matrix(y_true, y_pred, labels=[0, 1]).ravel()
    metrics["confusion_matrix"] = {"tn": int(tn), "fp": int(fp), "fn": int(fn), "tp": int(tp)}
    return metrics


def save_roc_curve(y_true: np.ndarray, y_prob: np.ndarray, out_path: Path) -> None:
    if len(np.unique(y_true)) < 2:
        return
    import matplotlib

    matplotlib.use("Agg")
    import matplotlib.pyplot as plt

    fpr, tpr, _ = roc_curve(y_true, y_prob)
    plt.figure(figsize=(6, 5))
    plt.plot(fpr, tpr, label="ROC")
    plt.plot([0, 1], [0, 1], "--", color="gray")
    plt.xlabel("False positive rate")
    plt.ylabel("True positive rate")
    plt.title("LSTM ROC curve")
    plt.legend()
    out_path.parent.mkdir(parents=True, exist_ok=True)
    plt.savefig(out_path, dpi=120, bbox_inches="tight")
    plt.close()


def write_json(path: Path, payload: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2), encoding="utf-8")
