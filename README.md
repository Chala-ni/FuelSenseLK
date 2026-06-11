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
├── backend/                 # Django REST API (planned)
├── mobile/                  # Flutter mobile app (planned)
├── web/                     # Flutter Web dashboard (planned)
└── ml/                      # ML models and data pipeline (planned)
```

## Status

🚧 **Project initiation** — repository setup and development planning in progress.

## Author

**Hansika Chalani**  
hansikachalani875@gmail.com

## License

This project is developed as an academic final year project. All rights reserved unless otherwise specified.
