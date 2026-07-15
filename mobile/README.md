# FuelSense LK — Mobile App

**Status:** Sprint 4 — driver modules scaffolded

## Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) 3.16+
- Backend running at `http://127.0.0.1:8000`

## Setup

```bash
cd mobile
flutter pub get
flutter run
```

Android emulator uses `10.0.2.2` for host localhost:

```bash
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api
```

## Driver features (Sprint 4)

| Tab | Feature |
|-----|---------|
| Map | Nearby stations, stock colours, crowd report |
| Find | Smart finder with radius + min stock filters |
| QR | Vehicle QR for attendant scan |
| History | Dispense log + monthly chart |
| Profile | Vehicles, price charts, logout |

## Demo account

- Email: `driver@demo.fuelsense.lk`
- Password: `DemoPass123`

## Project structure

```
lib/
├── core/api/          # ApiClient with JWT
├── core/models/       # Station, Vehicle, DispenseRecord
├── features/auth/     # Login
├── features/driver/   # M1–M8 screens + DriverShell
├── features/attendant/# Sprint 5 placeholder
└── services/          # Auth, repositories, WebSocket
```
