"""
Train stacked LSTM depletion-risk classifiers (Sprint 2 — full pipeline).

- Architecture: 2-layer LSTM (128 -> 64) with dropout
- Splits: train Jan-Sep / val Oct-Nov / test Dec (strict temporal)
- Scaler fit on train only
- Metrics: AUC, accuracy, precision, recall, F1 on val + test
"""

from __future__ import annotations

import argparse
import pickle
import time
from pathlib import Path

import numpy as np
import pandas as pd
from sklearn.preprocessing import StandardScaler
from sklearn.utils.class_weight import compute_class_weight

from config import (
    DATA_RAW,
    DATA_SPLITS,
    LSTM_AUC_PROPOSAL,
    LSTM_BATCH_SIZE,
    LSTM_CLASSIFICATION_THRESHOLD,
    LSTM_DROPOUT,
    LSTM_EARLY_STOPPING_PATIENCE,
    LSTM_EPOCHS,
    LSTM_FEATURE_COLUMNS,
    LSTM_HORIZONS_HOURS,
    LSTM_LEARNING_RATE,
    LSTM_LOOKBACK_HOURS,
    LSTM_UNITS,
    REPORTS,
)
from ml_utils import (
    classification_metrics,
    load_splits,
    save_roc_curve,
    set_seed,
    split_row_counts,
    stack_station_sequences,
    write_json,
)

try:
    from tensorflow import keras
    from tensorflow.keras import callbacks, layers
except ImportError:
    keras = None


def build_lstm_model(input_shape: tuple[int, int]) -> keras.Model:
    model = keras.Sequential(
        [
            layers.Input(shape=input_shape),
            layers.LSTM(LSTM_UNITS[0], return_sequences=True),
            layers.Dropout(LSTM_DROPOUT),
            layers.LSTM(LSTM_UNITS[1]),
            layers.Dropout(LSTM_DROPOUT),
            layers.Dense(32, activation="relu"),
            layers.Dense(1, activation="sigmoid"),
        ],
        name="depletion_risk_lstm",
    )
    model.compile(
        optimizer=keras.optimizers.Adam(learning_rate=LSTM_LEARNING_RATE),
        loss="binary_crossentropy",
        metrics=[
            keras.metrics.AUC(name="auc"),
            keras.metrics.Precision(name="precision"),
            keras.metrics.Recall(name="recall"),
            keras.metrics.BinaryAccuracy(name="accuracy"),
        ],
    )
    return model


def scale_sequences(scaler: StandardScaler, X: np.ndarray, fit: bool = False) -> np.ndarray:
    n, lookback, feats = X.shape
    flat = X.reshape(-1, feats)
    if fit:
        flat = scaler.fit_transform(flat)
    else:
        flat = scaler.transform(flat)
    return flat.reshape(n, lookback, feats)


def train_horizon(
    horizon: int,
    fuel_type: str,
    station_ids: list[int],
    train_df: pd.DataFrame,
    val_df: pd.DataFrame,
    test_df: pd.DataFrame,
) -> dict:
    print(f"\n=== LSTM horizon {horizon}h | {fuel_type} | {len(station_ids)} stations ===")

    X_train, y_train = stack_station_sequences(train_df, station_ids, horizon)
    X_val, y_val = stack_station_sequences(val_df, station_ids, horizon)
    X_test, y_test = stack_station_sequences(test_df, station_ids, horizon)

    print(f"  Windows — train: {len(y_train):,}  val: {len(y_val):,}  test: {len(y_test):,}")
    print(f"  Positive rate — train: {y_train.mean():.2%}  val: {y_val.mean():.2%}  test: {y_test.mean():.2%}")

    scaler = StandardScaler()
    X_train = scale_sequences(scaler, X_train, fit=True)
    X_val = scale_sequences(scaler, X_val)
    X_test = scale_sequences(scaler, X_test)

    classes = np.unique(y_train)
    weights = compute_class_weight("balanced", classes=classes, y=y_train)
    class_weight = {int(c): float(w) for c, w in zip(classes, weights)}

    model = build_lstm_model((LSTM_LOOKBACK_HOURS, len(LSTM_FEATURE_COLUMNS)))

    models_dir = Path(__file__).resolve().parents[1] / "models" / "lstm"
    models_dir.mkdir(parents=True, exist_ok=True)
    ckpt_path = models_dir / f"depletion_risk_{horizon}h_best.keras"

    cb = [
        callbacks.EarlyStopping(
            monitor="val_auc",
            mode="max",
            patience=LSTM_EARLY_STOPPING_PATIENCE,
            restore_best_weights=True,
            verbose=1,
        ),
        callbacks.ModelCheckpoint(ckpt_path, monitor="val_auc", mode="max", save_best_only=True, verbose=0),
        callbacks.ReduceLROnPlateau(monitor="val_loss", factor=0.5, patience=3, min_lr=1e-6, verbose=1),
    ]

    t0 = time.time()
    history = model.fit(
        X_train,
        y_train,
        validation_data=(X_val, y_val),
        epochs=LSTM_EPOCHS,
        batch_size=LSTM_BATCH_SIZE,
        class_weight=class_weight,
        callbacks=cb,
        verbose=2,
    )
    train_seconds = round(time.time() - t0, 1)

    model.save(models_dir / f"depletion_risk_{horizon}h.keras")
    with (models_dir / f"scaler_{horizon}h.pkl").open("wb") as f:
        pickle.dump(scaler, f)

    y_val_prob = model.predict(X_val, verbose=0).ravel()
    y_test_prob = model.predict(X_test, verbose=0).ravel()

    val_metrics = classification_metrics(y_val, y_val_prob, LSTM_CLASSIFICATION_THRESHOLD)
    test_metrics = classification_metrics(y_test, y_test_prob, LSTM_CLASSIFICATION_THRESHOLD)

    charts_dir = REPORTS / "charts"
    save_roc_curve(y_val, y_val_prob, charts_dir / f"lstm_roc_val_{horizon}h.png")
    save_roc_curve(y_test, y_test_prob, charts_dir / f"lstm_roc_test_{horizon}h.png")

    best_epoch = int(np.argmax(history.history.get("val_auc", [0])) + 1)
    summary = {
        "model": "stacked_lstm",
        "architecture": {
            "layers": [f"LSTM({LSTM_UNITS[0]})", f"LSTM({LSTM_UNITS[1]})", "Dense(32)", "Dense(1,sigmoid)"],
            "lookback_hours": LSTM_LOOKBACK_HOURS,
            "features": list(LSTM_FEATURE_COLUMNS),
        },
        "hyperparameters": {
            "epochs_max": LSTM_EPOCHS,
            "epochs_trained": len(history.history["loss"]),
            "best_epoch_val_auc": best_epoch,
            "batch_size": LSTM_BATCH_SIZE,
            "learning_rate": LSTM_LEARNING_RATE,
            "dropout": LSTM_DROPOUT,
            "early_stopping_patience": LSTM_EARLY_STOPPING_PATIENCE,
            "classification_threshold": LSTM_CLASSIFICATION_THRESHOLD,
            "class_weight": class_weight,
        },
        "horizon_hours": horizon,
        "fuel_type": fuel_type,
        "stations_used": len(station_ids),
        "window_counts": {
            "train": int(len(y_train)),
            "val": int(len(y_val)),
            "test": int(len(y_test)),
        },
        "validation": val_metrics,
        "test": test_metrics,
        "target_auc": LSTM_AUC_PROPOSAL,
        "meets_target_val_auc": (val_metrics.get("auc") or 0) >= LSTM_AUC_PROPOSAL,
        "meets_target_test_auc": (test_metrics.get("auc") or 0) >= LSTM_AUC_PROPOSAL,
        "train_seconds": train_seconds,
        "history": {k: [round(float(v), 4) for v in vals[-5:]] for k, vals in history.history.items()},
    }

    print(f"  Val  — AUC: {val_metrics.get('auc')}  Acc: {val_metrics['accuracy']}  F1: {val_metrics['f1']}")
    print(f"  Test — AUC: {test_metrics.get('auc')}  Acc: {test_metrics['accuracy']}  F1: {test_metrics['f1']}")
    print(f"  Trained in {train_seconds}s ({summary['hyperparameters']['epochs_trained']} epochs)")

    return summary


def main() -> None:
    parser = argparse.ArgumentParser(description="Train LSTM depletion risk models (full pipeline)")
    parser.add_argument("--fuel-type", default="petrol_92")
    parser.add_argument("--horizons", default="6,12,24", help="Comma-separated horizons")
    parser.add_argument("--max-stations", type=int, default=0, help="0 = all stations")
    args = parser.parse_args()

    if keras is None:
        raise SystemExit("TensorFlow not installed. Run: pip install tensorflow")

    set_seed()
    horizons = [int(h) for h in args.horizons.split(",")]

    train_df, val_df, test_df = load_splits(fuel_type=args.fuel_type)
    stations = pd.read_csv(DATA_RAW / "stations.csv")
    station_ids = sorted(stations["station_id"].astype(int).unique())
    if args.max_stations > 0:
        station_ids = station_ids[: args.max_stations]

    split_info = split_row_counts(train_df, val_df, test_df)
    all_summaries = {
        "split_info": split_info,
        "fuel_type": args.fuel_type,
        "stations_used": len(station_ids),
        "horizons": {},
    }

    for horizon in horizons:
        summary = train_horizon(horizon, args.fuel_type, station_ids, train_df, val_df, test_df)
        all_summaries["horizons"][str(horizon)] = summary
        write_json(REPORTS / f"lstm_performance_{horizon}h.json", summary)

    write_json(REPORTS / "lstm_performance.json", all_summaries)
    print(f"\nReports -> {REPORTS}")


if __name__ == "__main__":
    main()
