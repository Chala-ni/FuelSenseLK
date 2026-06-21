# UI/UX Performance Requirements Under High Load

**Lecturer amendment — CL/BSCSD/34/14**  
**Sprint:** 1 (specification) → Sprints 3–6 (implementation)  
**Status:** Specification complete

---

## 1. Purpose

FuelSense LK must remain responsive when many drivers view the national map simultaneously, WebSocket stock updates fire on every dispense, and admins load analytics over 200+ stations. This document defines performance budgets and implementation strategies.

---

## 2. Performance Budgets

| Surface | Metric | Target | Measured In |
|---------|--------|--------|-------------|
| Driver map — initial load | Time to interactive map with pins | < 2 seconds | Sprint 4 |
| Driver map — stock update | QR dispense → pin colour change | < 2 seconds | Sprint 6 |
| Smart finder API | `GET /api/stations/nearby/` | < 500ms | Sprint 6 |
| Attendant QR flow | Scan → confirm complete | < 15 seconds | Sprint 5 UAT |
| Web admin map — 200 stations | Initial render | < 3 seconds | Sprint 6 |
| Web analytics dashboard | Chart load | < 2 seconds | Sprint 6 |
| WebSocket fan-out | 50 concurrent clients, 10 dispenses/min | No client crash; UI stays responsive | Sprint 6 load test |

---

## 3. Mobile App (Flutter) — Driver Map

### 3.1 Map Marker Strategy

**Problem:** 200+ markers crash or lag on low-end Android devices.

**Solution:**
- On map load, fetch only stations within **visible viewport + 2km buffer** using `GET /api/stations/nearby/`
- Re-fetch on map pan end (debounced 300ms), not on every frame
- Use **marker clustering** when zoom level < 12 (cluster plugin or custom grouping)
- Limit rendered markers to **max 100**; show "Zoom in for more" toast

### 3.2 WebSocket Throttling (Client-Side)

**Problem:** Burst of dispense events causes excessive UI rebuilds.

**Solution:**
```dart
// Max 1 map refresh per station per second
final _updateThrottle = <int, DateTime>{};
void onStockUpdate(StockUpdate event) {
  final last = _updateThrottle[event.stationId];
  if (last != null && DateTime.now().difference(last) < Duration(seconds: 1)) return;
  _updateThrottle[event.stationId] = DateTime.now();
  _updateMarker(event);
}
```

### 3.3 List Pagination

- Fuel history: 20 records per page, infinite scroll
- Smart finder results: max 5 stations (already in spec)

---

## 4. Mobile App (Flutter) — Attendant

| Concern | Strategy |
|---------|----------|
| Scanner camera lag | Pre-initialise `mobile_scanner` on screen mount |
| Network retry on dispense | Optimistic UI with retry dialog; block double-submit |
| Stock panel updates | Single WebSocket subscription to own station only |

---

## 5. Flutter Web — Admin Dashboard

### 5.1 National Map (M12)

- **Viewport-based loading** — same as mobile; do not render all 200 pins at national zoom
- **District filter** reduces rendered set before map paint
- Lazy-load station detail panel on pin click (not pre-loaded)

### 5.2 Analytics Charts (M13)

- Pre-aggregate on backend (`/api/analytics/*`) — never send raw 1.75M rows to client
- Cache analytics responses server-side for **5 minutes** (Redis)
- Render charts with `fl_chart` using downsampled data (max 365 points per series)

### 5.3 Forecasting Dashboard (M14)

- Load Prophet chart on station selection (lazy), not on page load
- LSTM risk table: paginate 25 stations per page; default sort by 6h Red

### 5.4 Flutter Web Initial Load

Known limitation: ~1.5 MB Flutter engine download (3–8s on slow connections).

Mitigations:
- Show loading skeleton immediately
- Cache assets via service worker (Firebase Hosting)
- Document in dissertation limitations section

---

## 6. Backend Performance

| Endpoint | Strategy |
|----------|----------|
| `/api/stations/nearby/` | PostGIS GIST index on `location`; limit 50 results |
| `/api/dispense/` | Async WebSocket broadcast via Redis; don't block response |
| `/api/analytics/*` | Pre-computed Celery task every 15 min; serve from cache |
| WebSocket | Redis pub/sub; one channel per station (not one global flood) |

### Database Indexes (Sprint 2)

```sql
CREATE INDEX idx_station_location ON stations_station USING GIST (location);
CREATE INDEX idx_dispense_station_time ON dispense_dispenselog (station_id, timestamp DESC);
CREATE INDEX idx_stock_station ON stations_stocklevel (station_id, fuel_type);
```

---

## 7. Load Test Scenarios (Sprint 6)

| Scenario | Setup | Pass Criteria |
|----------|-------|---------------|
| Concurrent map viewers | 50 WebSocket clients subscribed to 20 stations | All receive update < 2s |
| Dispense burst | 10 dispenses in 30 seconds | No API errors; stock values consistent |
| Admin analytics | 5 admins load analytics simultaneously | Response < 2s each |
| Mobile low-end | Android device 3GB RAM, 50 map markers | Map scrolls at ≥ 30fps |

Tool: `locust` for API; manual/scripted WebSocket test for real-time.

---

## 8. Implementation Sprint Map

| Sprint | Performance Tasks |
|--------|-------------------|
| Sprint 1 | This requirements document ✅ |
| Sprint 2 | Database indexes; analytics pre-aggregation schema |
| Sprint 3 | WebSocket Redis pub/sub; paginated list APIs |
| Sprint 4 | Map viewport loading; marker clustering; WS throttle |
| Sprint 5 | Attendant flow timing optimisation |
| Sprint 6 | Load tests; API performance report; analytics caching |

---

## 9. Monitoring

Log and report in `docs/api_performance.md`:
- p50, p95, p99 response times for critical endpoints
- WebSocket message delivery latency (server timestamp → client receive)
- Any request exceeding budget flagged in Sprint 6 integration report
