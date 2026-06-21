# FuelSense LK — ML Pipeline

Synthetic dataset generation, validation, and model training for demand forecasting and depletion risk.

## Sprint 1 Setup

```bash
cd ml
python -m venv venv
venv\Scripts\activate        # Windows
pip install -r requirements.txt

# Generate data pipeline
python scripts/generate_stations.py
python scripts/generate_synthetic_dataset.py
python scripts/split_dataset.py
python scripts/validate_dataset.py
python scripts/crosscheck_cbsl.py
python scripts/generate_validation_charts.py
python scripts/fetch_open_meteo_weather.py
```

## Methodology (read first)

**`docs/dataset_design.md`** — station assumptions, demand rules, leakage prevention, success metrics.

## Outputs

| File | Description |
|------|-------------|
| `data/raw/stations.csv` | 200 stations + `station_demand_factor` |
| `data/processed/synthetic_station_hours.csv` | Master file with LSTM labels |
| `data/processed/weather.csv` | Per-district hourly rainfall + temperature |
| `data/processed/fuel_transactions.csv` | Dispense events |
| `data/processed/deliveries.csv` | Tanker deliveries + delay flags |
| `data/processed/stock_levels.csv` | Hourly stock snapshots |
| `data/splits/train.csv` / `val.csv` / `test.csv` | Temporal splits |
| `reports/dataset_validation.md` | Validation + bias audit |

## v2 Improvements

- District-specific weather (not global rainfall)
- Weekday/weekend demand seasonality
- Per-station personality factor
- Delivery delays (8% probability)
- Diesel vs petrol hourly profiles
- School holiday effect applied
- Calibration baked into generation (not post-hoc stock scaling)
- LSTM labels: `run_out_6h`, `run_out_12h`, `run_out_24h`

## Lecturer Amendments

- `docs/dataset_design.md`
- `docs/data_bias_and_leakage_controls.md`
- `docs/ml_scheduling_alignment.md`
- `docs/ui_performance_requirements.md`
