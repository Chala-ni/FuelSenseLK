import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

String fuelLabel(String code) {
  const labels = {
    'petrol_92': 'Petrol 92',
    'petrol_95': 'Petrol 95',
    'auto_diesel': 'Auto Diesel',
    'super_diesel': 'Super Diesel',
  };
  return labels[code] ?? code;
}

IconData fuelIcon(String code) => switch (code) {
      'petrol_92' || 'petrol_95' => Icons.local_gas_station_rounded,
      'auto_diesel' || 'super_diesel' => Icons.oil_barrel_rounded,
      _ => Icons.water_drop_rounded,
    };

Color stockPinColor(double? pct) => AppColors.stockColor(pct);
