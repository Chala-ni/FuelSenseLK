# LSTM Depletion Risk — 12h Horizon

## Architecture

| Component | Value |
|-----------|-------|
| Model | Stacked LSTM |
| Layers | LSTM(128) -> LSTM(64) -> Dense(32) -> Dense(1,sigmoid) |
| Lookback | 12 hours |
| Features / step | stock_percentage, hour_of_day, rainfall_mm, is_poya_day, is_weekday, demand_litres |

## Hyperparameters

| Parameter | Value |
|-----------|-------|
| Max epochs | 50 |
| Epochs trained | 44 |
| Best epoch (val AUC) | 37 |
| Batch size | 512 |
| Learning rate | 0.001 |
| Dropout | 0.3 |
| Early stopping patience | 7 |
| Classification threshold | 0.5 |

## Dataset Windows

| Split | Windows | Positive rate |
|-------|---------|-----------------|
| Train | 1,308,000 | (see training log) |
| Validation | 290,400 | 0.133 |
| Test | 146,400 | 0.1343 |

## Validation Metrics

| Metric | Value |
|--------|-------|
| AUC | **0.999** |
| Accuracy | 0.9835 |
| Precision | 0.8935 |
| Recall | 0.9942 |
| F1 | 0.9412 |
| Confusion matrix | TN=247188 FP=4579 FN=224 TP=38409 |

## Test Metrics (held-out December)

| Metric | Value |
|--------|-------|
| AUC | **0.999** |
| Accuracy | 0.9825 |
| Precision | 0.8884 |
| Recall | 0.9945 |
| F1 | 0.9385 |
| Meets AUC target (>=0.78) | Yes |

ROC charts: `reports/charts/lstm_roc_val_12h.png`, `lstm_roc_test_12h.png`
