# Dataset Validation Report (v2)

**Generated:** 2026-06-11 15:51 UTC

## Volume Anchor

| Metric | Value |
|--------|-------|
| Annual demand | 2,416,063,001 L |
| Anchor | 2,400,000,000 L |
| Deviation | 0.67% |
| Within ±5.0% | Yes |

## LSTM Label Health

- **run_out_6h:** 3.89% positive (OK)
- **run_out_12h:** 7.78% positive (OK)
- **run_out_24h:** 15.53% positive (OK)

## Weather Variation (District-Level)

- Districts: 23
- Mean rainfall range: 0.220 – 0.667 mm
- Districts differ: Yes

## Weekday vs Weekend Demand

- Weekday mean: 395.60 L/hr
- Weekend mean: 308.24 L/hr

## CBSL Import Cross-Check

- Pearson r (monthly shape): -0.4155
- Acceptable (r ≥ 0.5): No

## Validation Charts

See `ml/reports/charts/` for station type, hourly profile, monthly trend, weekday/weekend, LSTM labels.

## Methodology

See `ml/docs/dataset_design.md` for full assumptions.