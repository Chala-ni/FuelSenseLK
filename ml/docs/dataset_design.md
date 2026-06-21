# FuelSense LK — Synthetic Dataset Design Methodology

**Document version:** 2.0  
**Author:** Hansika Chalani  
**Purpose:** Define data generation assumptions before implementation. Forms the basis of the dissertation Data & Methods chapter and addresses lecturer feedback on synthetic bias and leakage control.

---

## 1. Design Goals

| Goal | Rationale |
|------|-----------|
| Realistic temporal patterns | Prophet requires meaningful seasonality (daily, weekly, holiday) |
| Station heterogeneity | Avoid synthetic bias where all stations behave identically |
| Physical stock consistency | Stock = previous − demand + delivery (never randomly assigned) |
| Intentional stock-out events | LSTM needs positive depletion cases to learn |
| No data leakage | LSTM/Prophet train features use only information known at prediction time |
| Calibrated aggregate volume | Annual total within ±5% of publicly reported fuel sector figures |

---

## 2. Dataset Dimensions

| Parameter | Value |
|-----------|-------|
| Stations | 200 |
| Duration | 12 months (2025-01-01 → 2025-12-31) |
| Granularity | Hourly |
| Expected rows (master) | ~6.1M (200 stations × 8,760 hours × ~3.5 fuel types avg) |

---

## 3. Station Profiles

### 3.1 Station Type Distribution

| Type | Target % | Tank Capacity | Delivery Interval | Volume Weight |
|------|----------|---------------|-------------------|---------------|
| Urban | 35% | 30,000 L | Every 2–3 days | 1.4× |
| Suburban | 30% | 20,000 L | Every 3–5 days | 1.0× |
| Highway | 20% | 50,000 L | Every 3–4 days | 1.8× |
| Rural | 15% | 12,000 L | Every 4–7 days | 0.6× |

### 3.2 Station Personality Factor

Each station receives a persistent multiplier assigned once at creation:

```
station_demand_factor ~ Uniform(0.80, 1.20)
```

Applied to all demand at that station throughout the year. Creates unique behavioural identity beyond station type.

### 3.3 Fuel Types per Station

| Station Type | Fuels Offered |
|--------------|---------------|
| Highway, Urban, Suburban | Petrol 92, Petrol 95, Auto Diesel, Super Diesel |
| Rural | Petrol 92, Auto Diesel only |

### 3.4 Fuel Volume Share (Network-Wide)

| Fuel Type | Share |
|-----------|-------|
| Petrol 92 | 35% |
| Petrol 95 | 15% |
| Auto Diesel | 40% |
| Super Diesel | 10% |

---

## 4. Demand Model

### 4.1 Base Formula

```
hourly_demand = hourly_base
              × hourly_profile[fuel_type][hour]
              × station_demand_factor
              × weekday_factor
              × holiday_factors
              × weather_factor
              × noise
```

Where `hourly_base` is calibrated so the **network annual total matches the volume anchor** before simulation (not scaled post-hoc on stock).

### 4.2 Hourly Profiles

**Petrol profile** — Colombo commuting peaks (7–9 AM, 5–7 PM).

**Diesel profile** — Sustained midday commercial demand (10 AM–4 PM elevated vs petrol).

### 4.3 Weekday Seasonality

| Period | Multiplier |
|--------|------------|
| Monday–Friday | 1.10× |
| Saturday–Sunday | 0.85× |

### 4.4 Holiday & Event Effects

| Event | Effect |
|-------|--------|
| Poya day | Demand −25% |
| School holiday | Demand −5% |
| Day before price increase | Demand +50% |
| Day of price increase | Demand −15% (post-rush normalisation) |
| Heavy rain (>5 mm) | Demand −12% |

### 4.5 Random Noise

```
noise ~ Normal(1.0, σ=0.08)
```

---

## 5. Weather Model

### 5.1 District-Specific Rainfall

Rainfall is generated **per district**, not globally:

```
rainfall[district, timestamp] = base_exponential × district_rainfall_factor × monsoon_seasonality
```

District factors reflect wet-zone (Colombo, Ratnapura) vs dry-zone (Jaffna, Mannar) differences.

### 5.2 Temperature (Optional Feature)

Simulated per district for future Prophet regressors.

### 5.3 Future Enhancement

Replace simulated weather with **Open-Meteo Archive API** hourly data per district centroid.

---

## 6. Delivery & Stock Model

### 6.1 Stock Equation

```
stock[t] = stock[t-1] - demand[t] + delivery[t]
stock[t] >= 0
```

### 6.2 Delivery Schedule

- Interval depends on station type (see §3.1)
- Delivery volume: 60–100% of tank capacity
- Resets depletion clock for that fuel type

### 6.3 Delivery Disruptions (Stock-Out Events)

To create realistic shortages for LSTM:

| Disruption | Probability | Effect |
|------------|-------------|--------|
| Delivery delay | 8% per scheduled delivery | Delay 1–2 days |
| Demand surge event | 2% per day | Demand ×1.5 for that hour |

Target: **5–10% of station-months** experience at least one near-stock-out event (stock < 5%).

---

## 7. LSTM Depletion Labels

Computed **after** stock simulation using **future stock only for labelling** (not as input features).

For each `(station_id, fuel_type, timestamp)`:

```
future_min_stock_Nh = min(stock[t+1 : t+N])
run_out_Nh = 1  if future_min_stock_Nh <= 0  OR  stock_percentage drops below 5%
run_out_Nh = 0  otherwise
```

Horizons: N ∈ {6, 12, 24} hours.

**Leakage rule:** Labels use future data; input features for LSTM use only `[t-11 … t]` stock/demand and contextual features at `t`.

---

## 8. Train / Validation / Test Split

| Split | Months | Rows (approx.) | Purpose |
|-------|--------|----------------|---------|
| Train | Jan–Sep (1–9) | ~75% | Model fitting |
| Validation | Oct–Nov (10–11) | ~17% | Hyperparameter tuning |
| Test | Dec (12) | ~8% | Final evaluation only |

**Rules:**
- Strict temporal ordering — no shuffle
- Scalers fit on train only
- No test statistics in feature engineering

---

## 9. Output Files

| File | Contents |
|------|----------|
| `data/raw/stations.csv` | Station metadata + `station_demand_factor` |
| `data/processed/weather.csv` | `timestamp, district, rainfall_mm, temperature_c` |
| `data/processed/fuel_transactions.csv` | `station_id, timestamp, fuel_type, litres_dispensed` |
| `data/processed/deliveries.csv` | `station_id, timestamp, fuel_type, delivery_litres, was_delayed` |
| `data/processed/stock_levels.csv` | `station_id, timestamp, fuel_type, stock_litres, stock_percentage` |
| `data/processed/synthetic_station_hours.csv` | Master file with all features + LSTM labels |
| `data/splits/train.csv` / `val.csv` / `test.csv` | Temporal splits |
| `data/splits/leakage_audit.json` | Split verification |

---

## 10. Success Metrics (Pre-Defined)

### Prophet — Demand Forecasting

| Metric | Target |
|--------|--------|
| MAPE (held-out 3-month test) | ≤ 15% (stretch) / ≤ 20% (proposal minimum) |
| Reported per station type | highway, urban, suburban, rural |

### LSTM — Depletion Risk

| Metric | Target |
|--------|--------|
| AUC (12-hour horizon) | ≥ 0.80 (stretch) / ≥ 0.78 (proposal minimum) |
| Precision / Recall / F1 | Reported per horizon |
| Positive class rate | 5–15% (verify stock-outs exist) |

---

## 11. Known Limitations (Dissertation Honesty)

1. Synthetic data calibrated to aggregate statistics, not real pump readings
2. Seasonality assumptions from literature, not measured SL data
3. Delivery disruptions are simulated, not from logistics records
4. Weather is simulated in Sprint 1; Open-Meteo integration planned
5. No 2022-crisis-scale supply shocks in dataset
6. CPC multi-operator stations not included

---

## 12. Implementation Map

| Component | Script |
|-----------|--------|
| Station seed data | `scripts/generate_stations.py` |
| Full dataset generation | `scripts/generate_synthetic_dataset.py` |
| Temporal splits + leakage audit | `scripts/split_dataset.py` |
| Validation + bias report | `scripts/validate_dataset.py` |
| Bias/leakage controls doc | `docs/data_bias_and_leakage_controls.md` |

---

*This document must be updated if generation assumptions change. Any change requires re-generation of dataset and re-validation.*
