"""FuelSense LK — ML pipeline configuration constants."""

from pathlib import Path

ML_ROOT = Path(__file__).resolve().parents[1]
DATA_RAW = ML_ROOT / "data" / "raw"
DATA_PROCESSED = ML_ROOT / "data" / "processed"
DATA_SPLITS = ML_ROOT / "data" / "splits"
REPORTS = ML_ROOT / "reports"

# Dataset dimensions
NUM_STATIONS = 200
HOURS_PER_YEAR = 8760
START_DATE = "2025-01-01 00:00:00"
END_DATE = "2025-12-31 23:00:00"

# Calibration anchor — Lanka IOC annual report (refine with exact PDF figure)
ANNUAL_VOLUME_LITRES_ANCHOR = 2_400_000_000
ANCHOR_TOLERANCE_PCT = 5.0

# Station type distribution (dataset_design.md §3.1)
STATION_TYPES = ("highway", "urban", "suburban", "rural")
STATION_TYPE_WEIGHTS = {
    "urban": 0.35,
    "suburban": 0.30,
    "highway": 0.20,
    "rural": 0.15,
}

STATION_VOLUME_WEIGHT = {
    "highway": 1.8,
    "urban": 1.4,
    "suburban": 1.0,
    "rural": 0.6,
}

# Delivery intervals by station type (days)
DELIVERY_INTERVAL_BY_TYPE = {
    "urban": (2, 3),
    "suburban": (3, 5),
    "highway": (3, 4),
    "rural": (4, 7),
}

DELIVERY_DELAY_PROB = 0.08
DELIVERY_DELAY_DAYS = (1, 2)
DEMAND_SURGE_PROB = 0.02
DEMAND_SURGE_MULTIPLIER = 1.5

# Station personality (assigned once per station)
STATION_FACTOR_MIN = 0.80
STATION_FACTOR_MAX = 1.20

# Demand modifiers
NOISE_SIGMA_PCT = 0.08
POYA_DEMAND_REDUCTION = 0.25
SCHOOL_HOLIDAY_REDUCTION = 0.05
PRE_PRICE_CHANGE_SURGE = 0.50
PRICE_CHANGE_DAY_REDUCTION = 0.15
RAINFALL_DEMAND_REDUCTION = 0.12
RAINFALL_THRESHOLD_MM = 5.0
WEEKDAY_MULTIPLIER = 1.10
WEEKEND_MULTIPLIER = 0.85

# Temporal splits (lecturer amendment)
TRAIN_END_MONTH = 9
VAL_END_MONTH = 11

FUEL_TYPES = ("petrol_92", "petrol_95", "auto_diesel", "super_diesel")
FUEL_TYPE_SHARE = {
    "petrol_92": 0.35,
    "petrol_95": 0.15,
    "auto_diesel": 0.40,
    "super_diesel": 0.10,
}

DIESEL_FUEL_TYPES = frozenset({"auto_diesel", "super_diesel"})

# Petrol — Colombo commuting peaks
HOURLY_PROFILE_PETROL = {
    0: 0.25, 1: 0.20, 2: 0.18, 3: 0.18, 4: 0.22, 5: 0.35,
    6: 0.55, 7: 0.90, 8: 1.00, 9: 0.75, 10: 0.60, 11: 0.55,
    12: 0.65, 13: 0.60, 14: 0.55, 15: 0.60, 16: 0.75, 17: 0.95,
    18: 1.00, 19: 0.80, 20: 0.60, 21: 0.50, 22: 0.40, 23: 0.30,
}

# Diesel — sustained midday commercial traffic
HOURLY_PROFILE_DIESEL = {
    0: 0.30, 1: 0.25, 2: 0.22, 3: 0.22, 4: 0.28, 5: 0.40,
    6: 0.50, 7: 0.65, 8: 0.75, 9: 0.85, 10: 0.95, 11: 1.00,
    12: 1.00, 13: 0.95, 14: 0.90, 15: 0.88, 16: 0.85, 17: 0.80,
    18: 0.70, 19: 0.55, 20: 0.45, 21: 0.38, 22: 0.35, 23: 0.32,
}

TANK_CAPACITY = {
    "highway": 50000,
    "urban": 30000,
    "suburban": 20000,
    "rural": 12000,
}

# District rainfall intensity (wet zone vs dry zone)
DISTRICT_RAINFALL_FACTOR = {
    "Colombo": 1.30, "Gampaha": 1.25, "Kalutara": 1.20, "Ratnapura": 1.35,
    "Kegalle": 1.15, "Kandy": 1.10, "Nuwara Eliya": 1.40, "Galle": 1.20,
    "Matara": 1.15, "Hambantota": 0.70, "Badulla": 1.00, "Monaragala": 0.75,
    "Kurunegala": 0.95, "Puttalam": 0.80, "Anuradhapura": 0.65,
    "Polonnaruwa": 0.70, "Trincomalee": 0.85, "Batticaloa": 0.90,
    "Ampara": 0.85, "Jaffna": 0.50, "Mannar": 0.45, "Vavuniya": 0.55,
    "Mullaitivu": 0.50, "Kilinochchi": 0.48,
}

# LSTM
LSTM_LOOKBACK_HOURS = 12
LSTM_HORIZONS_HOURS = (6, 12, 24)
STOCKOUT_THRESHOLD_PCT = 5.0

# ML targets (dataset_design.md §10)
PROPHET_MAPE_TARGET = 0.15
PROPHET_MAPE_PROPOSAL = 0.20
LSTM_AUC_TARGET = 0.80
LSTM_AUC_PROPOSAL = 0.78

# Scheduling
PROPHET_SCHEDULE_CRON = "0 2 * * *"
LSTM_SCHEDULE_CRON = "0 * * * *"
PROPHET_FORECAST_HOURS = 72
RANDOM_SEED = 42
