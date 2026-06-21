# Prophet vs. LSTM Scheduling Alignment

**Lecturer amendment — CL/BSCSD/34/14**  
**Sprint:** 1 (specification) → Sprints 2–3 (implementation)  
**Status:** Specification complete

---

## 1. Problem

Prophet and LSTM serve **different forecasting purposes**. Without explicit alignment, admins could receive conflicting signals — e.g., Prophet predicts low demand tomorrow while LSTM flags critical depletion in 6 hours. This document defines how both models work together in the FuelSense LK scheduling workflow.

---

## 2. Model Roles

| Model | Question Answered | Output | Schedule |
|-------|-------------------|--------|----------|
| **Prophet** | "How much fuel will this station need over the next 24–72 hours?" | Hourly demand forecast + confidence intervals | **Nightly at 02:00** (Celery) |
| **LSTM** | "What is the probability this station runs out in 6/12/24 hours?" | Depletion probability + Green/Amber/Red tier | **Hourly at :00** (Celery) |

**ARIMA** is trained for academic baseline comparison only — not used in production scheduling.

---

## 3. Scheduling Decision Matrix

Admin dashboard combines both outputs using this priority logic:

| LSTM 6h Risk | Prophet 24h Demand vs Stock | Recommended Action | Urgency |
|--------------|----------------------------|--------------------|---------|
| 🔴 Red (>60%) | Any | **Dispatch tanker immediately** | Critical |
| 🟠 Amber (20–60%) | Demand exceeds current stock within 24h | **Schedule delivery within 12h** | High |
| 🟠 Amber | Demand manageable with current stock | **Monitor; review at next LSTM cycle** | Medium |
| 🟢 Green (<20%) | Demand exceeds stock in 48–72h | **Schedule proactive delivery** (Prophet-driven) | Planned |
| 🟢 Green | Demand below stock buffer | **No action required** | Low |

### Stock Buffer Rule

```
Required Stock = Prophet predicted demand (next 24h) × 1.2 safety factor
If current stock < Required Stock → flag for proactive scheduling
```

---

## 4. Cadence Alignment

```
Hourly (every :00)                Nightly (02:00)
─────────────────                 ─────────────────
LSTM recalculates                 Prophet regenerates
depletion risk for                72h demand forecast
all stations                      for all stations
       │                                 │
       ▼                                 ▼
  Urgent alerts                   Delivery planning
  (FCM to admin)                  (dashboard schedule view)
       │                                 │
       └──────────┬──────────────────────┘
                  ▼
         Admin Forecasting Dashboard (M14)
         ┌─────────────────────────────────┐
         │ LSTM Risk Panel  │ Prophet Panel │
         │ (sorted by 6h)   │ (72h chart)   │
         └─────────────────────────────────┘
```

### Celery Configuration (Sprint 3)

```python
# config/celery.py
PROPHET_CRON = "0 2 * * *"    # 02:00 daily
LSTM_CRON = "0 * * * *"       # every hour
```

Environment variables in `.env.example`:
- `PROPHET_CRON_HOUR=2`
- `LSTM_CRON_MINUTE=0`

---

## 5. Dashboard UI Alignment (Module M14)

The Forecasting Dashboard presents both panels **side-by-side**:

**Left panel — LSTM Depletion Risk (urgent)**
- Sortable table: all stations by 6h risk (Red first)
- Columns: station, fuel type, 6h/12h/24h probability, tier badge

**Right panel — Prophet Demand Forecast (planned)**
- Station selector → 72h hourly chart with confidence bands
- Component plots: trend, weekly, daily, holiday effects
- "Suggested delivery window" annotation when stock < 24h demand × 1.2

**Combined action row**
- Single "Schedule Delivery" CTA pre-filled when matrix triggers High or Critical urgency

---

## 6. Driver-Facing Alignment

| Signal | Source | Driver notification |
|--------|--------|---------------------|
| Station running low soon | LSTM 12h Amber/Red | FCM: "Station X running low — ~N hours" |
| Price increase tomorrow | Admin price log (not ML) | FCM: price change alert |
| Station has stock now | Real-time QR stock (not ML) | Map pin colour |

Prophet forecasts are **not shown directly to drivers** — they inform admin scheduling which indirectly keeps stations stocked.

---

## 7. Sprint Implementation Map

| Sprint | Task |
|--------|------|
| Sprint 1 | This specification document ✅ |
| Sprint 2 | Train Prophet + LSTM; persist outputs to DB schema |
| Sprint 3 | Celery tasks at aligned schedules; REST endpoints |
| Sprint 6 | M14 dashboard with side-by-side panels + decision matrix UI |

---

## 8. Evaluation Alignment

When reporting model performance in the dissertation:

- **Prophet** evaluated on MAPE (demand accuracy) — informs scheduling quality
- **LSTM** evaluated on AUC (stock-out detection) — informs alert quality
- Report a **combined scheduling simulation**: "If admin acted on LSTM Red + Prophet buffer rule, what % of stock-outs would have been prevented?"

This joint evaluation addresses the lecturer's scheduling alignment concern directly.
