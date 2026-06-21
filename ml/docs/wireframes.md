# FuelSense LK — UI Wireframe Specification (Sprint 1)

**Note:** Figma designs to be created from this spec. Screens defined for Sprint 4–6 implementation.

---

## 1. Driver Mobile — Map Home (M1)

```
┌─────────────────────────────────────┐
│ ☰  FuelSense LK          🔔  👤    │
├─────────────────────────────────────┤
│                                     │
│     [ OpenStreetMap full screen ]   │
│                                     │
│   🟢 🟡 🔴  station pins            │
│         📍 user location            │
│                                     │
├─────────────────────────────────────┤
│  [ Find Fuel Near Me ]              │
├─────────────────────────────────────┤
│  🗺 Map │ 🔍 Find │ QR │ History    │
└─────────────────────────────────────┘

Tap pin → Bottom sheet:
  Station name | 2.3 km
  Petrol 95: ████████░░ 64%  🟢
  Last updated: 2 min ago
  Depletion risk: Low (12h)
  [ Navigate ]  [ Report Status ]
```

---

## 2. Attendant Mobile — QR Scanner (M9)

```
┌─────────────────────────────────────┐
│  Nugegoda Station — Attendant Mode    │
├─────────────────────────────────────┤
│                                     │
│   ┌─────────────────────────────┐   │
│   │                             │   │
│   │    [ Camera QR Scanner ]    │   │
│   │                             │   │
│   └─────────────────────────────┘   │
│                                     │
│  Stock: 92 Oct 78% | Diesel 45%     │
├─────────────────────────────────────┤
│  Scanner │ Stock │ Delivery          │
└─────────────────────────────────────┘

After scan → Dispense form:
  Vehicle: CAB-1234 (Car)
  Fuel: [95 Octane ▼]
  Litres: [____]
  [ Confirm Dispense ]  ← target <15s
```

---

## 3. Admin Web — National Map + Forecasting (M12 + M14)

```
┌──────────────────────────────────────────────────────────┐
│ FuelSense Admin    Map | Analytics | Forecast | Crisis   │
├──────────────────────┬───────────────────────────────────┤
│                      │  LSTM Depletion Risk (urgent)     │
│  [ National Map ]    │  ┌─────────────────────────────┐  │
│   🟢🟡🔴 filters      │  │ Station    6h   12h   24h  │  │
│   District ▼         │  │ Kandy Rd   🔴   🔴    🟡   │  │
│                      │  │ Nugegoda   🟡   🟢    🟢   │  │
│                      │  └─────────────────────────────┘  │
│                      │  Prophet Forecast (selected)       │
│                      │  [ 72h demand chart + CI bands ]  │
│                      │  [ Schedule Delivery ]            │
└──────────────────────┴───────────────────────────────────┘
```

---

## 4. Design Tokens (Consistent Across Apps)

| Element | Value |
|---------|-------|
| Primary | `#1B5E20` (fuel green) |
| Stock Green | `#2ECC71` (>50%) |
| Stock Amber | `#F39C12` (<20%) |
| Stock Red | `#E74C3C` (out) |
| Stock Grey | `#95A5A6` (no data) |
| Font | System default / Roboto |

---

## 5. Figma Checklist

- [ ] Driver map home + station detail sheet
- [ ] Attendant scanner + dispense form + blocked quota screen
- [ ] Admin national map + forecasting side panel
- [ ] Station manager single-station dashboard
- [ ] Crisis mode toggle + quota configuration

*Create Figma file: `FuelSenseLK-Wireframes` and link here when ready.*
