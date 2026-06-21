# FuelSense LK — Annotated Literature Review (Sprint 1)

**Purpose:** Foundation for dissertation Chapter 2. Minimum 15 references from proposal + ML methodology.

---

## 1. Fuel Sector & Problem Domain

| # | Reference | Relevance to FuelSense LK |
|---|-----------|---------------------------|
| 1 | International Monetary Fund (2023). *Sri Lanka: 2023 Article IV Consultation*. | Documents 2022 fuel crisis context motivating real-time stock visibility |
| 2 | Ceylon Petroleum Corporation (2022). *CPC Statement on National Fuel Reserves*. | Evidence of near-zero national reserves during crisis |
| 3 | Lanka IOC PLC (2025). *Annual Report 2024/25*. | Calibration anchor for synthetic dataset annual volume |
| 4 | Lanka IOC PLC (2026). *Fuel Me App Features*. | Competitor gap analysis — no stock levels or forecasting |
| 5 | Central Bank of Sri Lanka (2026). *Imports — Monthly*. | CBSL petroleum import cross-check for dataset validation |
| 6 | Department of Motor Traffic, Sri Lanka (2024). *Annual Report*. | Vehicle fleet composition drives petrol vs diesel demand split |
| 7 | Sathyaprasad et al. (2020). *Vehicle ownership and travel demand in Sri Lanka*. | Empirical basis for commuting-hour demand peaks |

---

## 2. Time-Series Forecasting

| # | Reference | Relevance |
|---|-----------|-----------|
| 8 | Taylor & Letham (2018). *Forecasting at scale* (Prophet). | Core demand forecasting model; handles seasonality + holidays |
| 9 | Meta Open Source (2024). *Prophet documentation*. | Implementation reference for per-station Prophet models |
| 10 | Hochreiter & Schmidhuber (1997). *LSTM*. | Sequential model for depletion risk from stock time series |
| 11 | Hong et al. (2016). *Probabilistic energy forecasting*. | Synthetic dataset calibration methodology for energy demand |

---

## 3. Geospatial & Real-Time Systems

| # | Reference | Relevance |
|---|-----------|-----------|
| 12 | OpenStreetMap contributors (2024). *OSM / Overpass API*. | Station GPS coordinates for PostGIS nearest-station queries |
| 13 | Zippenfenig (2023). *Open-Meteo Weather API*. | Hourly rainfall/temperature for demand regressors |
| 14 | Django Software Foundation (2024). *Django Channels*. | WebSocket real-time stock broadcast architecture |
| 15 | Google (2024). *Firebase Cloud Messaging*. | Push notifications for depletion alerts |

---

## 4. Security & Evaluation

| # | Reference | Relevance |
|---|-----------|-----------|
| 16 | OWASP Foundation (2021). *OWASP Top Ten*. | Security review checklist for Sprint 6 |
| 17 | Brooke (1996). *SUS — System Usability Scale*. | UAT evaluation framework (Sprint 7, target ≥ 70) |

---

## 5. Key Findings Synthesised

1. **No existing Sri Lanka app** provides real-time fuel stock or demand forecasting (Lanka IOC Fuel Me confirms gap).
2. **Prophet** is appropriate for hourly demand with daily/weekly seasonality and holiday regressors.
3. **LSTM** suits depletion risk because stock-out depends on sequential consumption patterns, not threshold rules alone.
4. **Synthetic data** anchored to public aggregate statistics is an accepted bootstrap approach when pump-level data is unavailable (Hong et al., 2016).
5. **QR-based dispense logging** creates the data asset that makes both forecasting models possible.

---

## 6. Sri Lanka Demand Patterns Documented

| Pattern | Source | Implemented In Dataset |
|---------|--------|---------------------|
| Morning peak 7–9 AM | Proposal §3.1, Sathyaprasad et al. | Petrol hourly profile |
| Evening peak 5–7 PM | Proposal §3.1 | Petrol hourly profile |
| Midday diesel demand | Transport literature | Diesel hourly profile |
| Poya day demand drop | Gov calendar | `is_poya_day` −25% |
| Pre-price-change surge | Historical SL behaviour | `is_pre_price_change_day` +50% |
| Rain suppresses demand | Open-Meteo correlation | Rainfall > 5mm −12% |
| Weekday > weekend | Commuting logic | Mon–Fri ×1.10, Sat–Sun ×0.85 |

---

*Full bibliographic entries in FuelSense LK Proposal §12 References.*
