# FuelSense LK — Backend (Django)

**Status:** Sprint 3 — core APIs & real-time layer

## Setup

```bash
cd backend
pip install -r requirements.txt
python manage.py migrate
python manage.py seed_stations
python manage.py seed_stock_levels
python manage.py seed_prices
python manage.py create_demo_users
python manage.py runserver
```

Swagger: http://127.0.0.1:8000/api/docs/

## Sprint 3 API

| Endpoint | Role | Description |
|----------|------|-------------|
| `POST /api/dispense/` | Attendant | QR scan dispense → stock deduct + WebSocket |
| `GET /api/dispense/history/` | Driver/staff | Fuel history |
| `POST /api/delivery/` | Attendant | Log tanker delivery → stock add |
| `GET /api/delivery/history/` | Manager/admin | Delivery history |
| `POST /api/crowd-reports/` | Driver | Crowd status (expires 2h) |
| `GET /api/stations/{id}/crowd-reports/` | Public | Active crowd reports |
| `GET/POST /api/crisis/status/` | Public/admin | Crisis mode + quotas |
| `POST /api/crisis/activate/` | Admin | Enable crisis quotas |
| `GET /api/vehicles/{id}/qr/` | Driver | QR payload for vehicle |
| `POST /api/prices/` | Admin | Log price change |
| `ws/stations/{id}/?token=<jwt>` | Auth | Live stock WebSocket |

## Celery (optional — needs Redis)

```bash
celery -A config worker -l info
```

## ML inference (trained models)

Models load from `../ml/models/` (LSTM + Prophet). Heuristic fallback if files missing.

```bash
python manage.py run_ml_forecasts
# or
python manage.py seed_forecasts
```

Celery tasks `run_prophet_forecasts` and `run_depletion_risk` use the same services.

## Docker (PostgreSQL + Redis)

1. Start **Docker Desktop**
2. From project root: `docker compose up -d`
3. Uncomment database/redis lines in `.env`
4. `python manage.py migrate` and re-seed

Use `USE_POSTGIS=false` on Windows without GDAL (standard PostgreSQL backend).

## Tests

```bash
python manage.py test operations accounts stations
```
