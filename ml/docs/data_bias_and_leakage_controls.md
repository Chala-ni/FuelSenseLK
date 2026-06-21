# Synthetic Data Bias & Data Leakage Controls

**Lecturer amendment — CL/BSCSD/34/14**  
**Sprint:** 1  
**Status:** Active

---

## 1. Purpose

FuelSense LK trains Prophet and LSTM models on a **synthetic dataset** because real per-station hourly pump data is commercially confidential. This document records known biases in the synthetic data and the controls enforced to prevent **data leakage** during model training and evaluation.

---

## 2. Known Synthetic Data Biases

| Bias | Description | Mitigation |
|------|-------------|------------|
| **Geographic imbalance** | Stations weighted toward high-population districts (Colombo, Gampaha, Kurunegala) | Report metrics stratified by district and station type; document in dissertation |
| **Literature-based seasonality** | Hourly demand profile from transport literature, not measured SL pump data | Validate against CBSL monthly imports; note as limitation |
| **Simulated rainfall** | Sprint 1 uses synthetic rainfall; final version uses Open-Meteo | Replace before Sprint 2 model training |
| **No crisis shocks** | 2022-style supply collapse events not simulated | Document as out-of-distribution limitation |
| **Uniform noise model** | Gaussian σ=8% may under-represent real volatility | Compare rural vs highway station variance in validation report |
| **Delivery approximation** | Tanker arrivals every 3–7 days, not real route data | Cross-check stock-out frequency against manager persona expectations |

All biases are reported in `ml/reports/dataset_validation.md` and the dissertation Data & Methods chapter.

---

## 3. Data Leakage Controls

### 3.1 Temporal Split Policy (Mandatory)

| Split | Months | Purpose |
|-------|--------|---------|
| **Train** | 1–9 (Jan–Sep) | Model fitting |
| **Validation** | 10–11 (Oct–Nov) | Hyperparameter tuning |
| **Test** | 12 (Dec) | Final held-out evaluation only |

**Rules:**
- ❌ No random `train_test_split(shuffle=True)` on time-series rows
- ❌ No test-set statistics used to normalise train features
- ✅ Splits enforced in `ml/scripts/split_dataset.py`
- ✅ Audit written to `ml/data/splits/leakage_audit.json`

### 3.2 Prophet (Demand Forecasting)

| Risk | Control |
|------|---------|
| Future demand in regressors | Regressors (`is_poya_day`, `rainfall_mm`, etc.) are **calendar/weather features known at forecast origin** |
| Target in features | `demand_litres` is the target only — never included as a regressor |
| Test data in training | Prophet fitted on train months only; evaluated on test months only |

### 3.3 LSTM (Depletion Risk)

| Risk | Control |
|------|---------|
| Future stock in input window | Input window uses stock readings at **t, t−1, …, t−11 only** (12-hour causal lookback) |
| Future label in features | Label `stock_out_within_Nh` computed from future stock but **never fed as input** |
| Cross-station leakage | Each station's sequences generated independently; no station-A future in station-B features |
| Normalisation leakage | Scalers fit on **train split only**, applied to val/test |

### 3.4 Evaluation Reporting

Report all metrics **stratified by station type** (highway, urban, suburban, rural) to surface bias in model performance across station profiles.

---

## 4. v2 Bias Reductions (dataset_design.md)

| Issue | v2 Fix |
|-------|--------|
| Global rainfall | Per-district `weather.csv` |
| No weekday effect | Mon–Fri ×1.10, Sat–Sun ×0.85 |
| Identical stations | `station_demand_factor` per station (0.8–1.2) |
| Perfect deliveries | 8% delivery delay probability |
| Unused school holidays | −5% demand on school holiday dates |
| Same petrol/diesel profile | Separate hourly profiles per fuel class |
| Post-hoc stock scaling | Calibration factor applied before simulation |
| No LSTM labels | `run_out_6h`, `run_out_12h`, `run_out_24h` columns |

## 5. Verification Checklist

- [x] `split_dataset.py` creates non-overlapping temporal splits
- [x] `leakage_audit.json` confirms train_max < val_min < test_min
- [x] Bias audit in `validate_dataset.py` output
- [x] LSTM labels present with 5–25% positive rate target
- [x] District weather variation verified
- [ ] Open-Meteo rainfall integrated (Sprint 1 follow-up)
- [ ] CBSL monthly cross-check added (Sprint 1 follow-up)
- [ ] Scaler-fit-on-train-only enforced in Sprint 2 training notebooks

---

## 5. References

- Hong et al. (2016) — synthetic load data calibration methodology
- FuelSense LK Proposal §4.2.3 — dataset generation pipeline
- Lecturer feedback — CL/BSCSD/34/14
