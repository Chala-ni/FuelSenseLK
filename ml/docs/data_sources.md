# FuelSense LK — Data Sources Register (Sprint 1)

**Last updated:** June 2026

| Dataset | Source URL | Format | Local Path | Extracted | Status |
|---------|-----------|--------|------------|-----------|--------|
| Lanka IOC Annual Report 2024/25 | https://www.lankaioc.com/wp-content/uploads/2025/06/LIOC-AR-2024_25-Hires.pdf | PDF | — | May 2026 | Anchor: Rs. 276.29 Bn turnover cited in proposal |
| CBSL Petroleum Imports | https://www.cbsl.gov.lk/en/statistics/economic-indicators/external-sector | XLSX | `data/raw/cbsl_petroleum_imports_monthly.csv` | Jun 2026 | Monthly USD imports 2023–2025 (representative series) |
| Station GPS / list | https://www.lankaioc.com/shed-locator + OSM Overpass | Web/API | `data/raw/stations.csv` | Jun 2026 | 200 synthetic stations with district centroids |
| Open-Meteo Weather | https://archive-api.open-meteo.com/v1/archive | JSON/CSV | `data/raw/open_meteo_weather_2025.csv` | Jun 2026 | Per-district hourly rainfall + temperature |
| Sri Lanka Holidays | https://www.gov.lk | Calendar | `data/raw/holidays_sri_lanka_2025.csv` | Jun 2026 | Poya + school holidays + price change event |
| District Populations | https://www.statistics.gov.lk | Census 2012 | `data/raw/districts.csv` | Jun 2026 | 24 districts with population weights |
| Synthetic Master Dataset | Generated locally | CSV | `data/processed/synthetic_station_hours.csv` | Jun 2026 | 6.5M rows, v2 pipeline |
| Weather (processed) | Generated / fetched | CSV | `data/processed/weather.csv` | Jun 2026 | District-level simulated + Open-Meteo available |
| Train/Val/Test Splits | Generated | CSV | `data/splits/*.csv` | Jun 2026 | Temporal split with leakage audit |

---

## Volume Calibration

| Metric | Value |
|--------|-------|
| Network anchor | 2,400,000,000 litres/year |
| Synthetic annual total | 2,416,063,001 litres |
| Deviation | 0.67% |
| Tolerance | ±5% |

---

## API Endpoints Used

### Open-Meteo Archive
```
GET https://archive-api.open-meteo.com/v1/archive
  ?latitude={lat}&longitude={lon}
  &start_date=2025-01-01&end_date=2025-12-31
  &hourly=rainfall,temperature_2m
  &timezone=Asia/Colombo
```

Fetch script: `python scripts/fetch_open_meteo_weather.py`

---

## Data Not Yet Integrated (Future)

| Item | Planned Sprint |
|------|----------------|
| OSM Overpass live station scrape | Sprint 2 backend seed |
| Exact Lanka IOC litre volume from PDF | Manual extraction when needed |
| CBSL live XLSX auto-download | Optional enhancement |

---

## Licence Summary

| Source | Licence |
|--------|---------|
| OpenStreetMap | ODbL 1.0 |
| Open-Meteo | CC BY 4.0 |
| CBSL statistics | Public domain |
| Lanka IOC annual report | Public (company website) |
