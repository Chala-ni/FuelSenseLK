# Prophet Demand Forecasting — Performance Report

**FuelSense LK** | Full training pipeline

## Summary

| Metric | Value |
|--------|-------|
| Stations trained | 200 / 200 |
| Fuel type | petrol_92 |
| Granularity | hourly |
| Avg validation MAPE | **19.24%** |
| Avg test MAPE | **17.65%** |
| Target test MAPE | <= 20.0% |
| Meets target | Yes |
| Training time | 1697.4s |

## Temporal Split

| Split | Period |
|-------|--------|
| Train | months 1-9 |
| Validation | months 10-11 |
| Test | month 12+ |

## MAPE by Station Type

| Station type | Stations | Val MAPE | Test MAPE |
|--------------|----------|----------|-----------|
| highway | 42 | 18.81 | 17.08 |
| rural | 28 | 19.62 | 18.04 |
| suburban | 62 | 19.31 | 17.93 |
| urban | 68 | 19.28 | 17.59 |

## Methodology

- One Prophet model per station
- Regressors: is_poya_day, is_school_holiday, rainfall_mm, is_price_change_day
- Stan MCMC backend (no batch size / epochs)
- Strict temporal split per `ml/docs/data_bias_and_leakage_controls.md`
