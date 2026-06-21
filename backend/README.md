# FuelSense LK — Backend (Django)

**Status:** Sprint 2 — scaffolded

## Stack

- Django 5 + Django REST Framework
- SimpleJWT (access 15min / refresh 7d)
- drf-spectacular (Swagger)
- SQLite (local dev) or PostgreSQL + PostGIS (Docker)

## Setup

```bash
cd backend
python -m venv venv
venv\Scripts\activate
pip install -r requirements.txt
python manage.py migrate
python manage.py seed_stations
python manage.py runserver
```

Health check: http://127.0.0.1:8000/api/health/

## With Docker (PostGIS)

```bash
# From project root
docker compose up -d
# Set in .env: DATABASE_URL=postgresql://fuelsense:fuelsense_dev@localhost:5432/fuelsense
python manage.py migrate
python manage.py seed_stations
```

## Apps

| App | Purpose |
|-----|---------|
| `accounts` | Custom User model with roles (driver, attendant, manager, admin) |
| `stations` | Station model + `seed_stations` management command |
