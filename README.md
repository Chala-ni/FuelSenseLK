# FuelSense LK

An intelligent web and mobile-based fuel availability monitoring and demand forecasting system for Sri Lanka.

**Final Year Project** — Bachelor of Science (Honours) in Software Engineering

## Overview

FuelSense LK addresses the lack of real-time fuel stock visibility at petrol and diesel stations across Sri Lanka. The platform combines mandatory QR-based fuel dispensing logs with machine learning forecasting to deliver live stock updates, demand predictions, and depletion risk alerts to drivers, station staff, and administrators.

## Key Features

- **Driver mobile app** — Real-time station map with stock levels, smart recommendations, crowd reports, and personal fuel history
- **Station attendant app** — QR scan on every dispense to update live stock balances
- **Web dashboard** — Station manager and admin views with analytics, forecasting, crisis mode, and network management
- **Demand forecasting** — Prophet model for 24–72 hour hourly demand predictions
- **Depletion risk** — LSTM model for stock-out probability within 6, 12, or 24 hours

## Tech Stack

| Layer | Technology |
|-------|------------|
| Mobile | Flutter (iOS & Android) |
| Web dashboard | Flutter Web |
| Backend | Django REST Framework, Django Channels (WebSockets) |
| Task queue | Celery |
| Database | PostgreSQL + PostGIS |
| ML | Prophet, LSTM (TensorFlow/Keras) |

## Project Structure

```
FuelSenseLK/
├── backend/                 # Django REST API (Sprint 2+)
├── mobile/                  # Flutter mobile app (Sprint 4+)
├── web/                     # Flutter Web dashboard (Sprint 5+)
├── ml/                      # Dataset generation & ML training (Sprint 1–2)
├── docker-compose.yml       # PostgreSQL + PostGIS + Redis
└── docs/                    # Sprint plan & proposal (local, gitignored)
```

## Quick Start (Sprint 1)

```bash
# Infrastructure
docker-compose up -d

# ML data pipeline
cd ml
python -m venv venv
venv\Scripts\activate
pip install -r requirements.txt
python scripts/generate_stations.py
python scripts/generate_synthetic_dataset.py
python scripts/split_dataset.py
python scripts/validate_dataset.py
```

## Status

✅ **Sprint 1 complete** — validated synthetic dataset, documentation, dev environment.  
📋 **Sprint 2 next** — Prophet/LSTM training + Django backend scaffold.  
See `docs/SPRINT_PLAN.md` and `docs/SPRINT_1_COMPLETION.md`.

## Author

**Hansika Chalani**  
hansikachalani875@gmail.com

## License

This project is developed as an academic final year project. All rights reserved unless otherwise specified.
