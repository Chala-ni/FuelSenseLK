class Station {
  Station({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.fuelTypes,
    required this.stockLevels,
    this.distanceKm,
  });

  final int id;
  final String name;
  final double latitude;
  final double longitude;
  final List<String> fuelTypes;
  final List<StockLevel> stockLevels;
  final double? distanceKm;

  factory Station.fromJson(Map<String, dynamic> json) {
    final stocks = (json['stock_levels'] as List<dynamic>? ?? [])
        .map((e) => StockLevel.fromJson(e as Map<String, dynamic>))
        .toList();
    return Station(
      id: json['id'] as int,
      name: json['name'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      fuelTypes: List<String>.from(json['fuel_types'] as List? ?? []),
      stockLevels: stocks,
      distanceKm: (json['distance_km'] as num?)?.toDouble(),
    );
  }

  double? stockPct(String fuelType) {
    final match = stockLevels.where((s) => s.fuelType == fuelType);
    return match.isEmpty ? null : match.first.percentage;
  }
}

class StockLevel {
  StockLevel({required this.fuelType, required this.percentage, required this.currentLitres});

  final String fuelType;
  final double percentage;
  final double currentLitres;

  factory StockLevel.fromJson(Map<String, dynamic> json) => StockLevel(
        fuelType: json['fuel_type'] as String,
        percentage: double.parse(json['percentage'].toString()),
        currentLitres: double.parse(json['current_litres'].toString()),
      );
}

class Vehicle {
  Vehicle({required this.id, required this.plateNumber, required this.vehicleType, required this.qrId, required this.isActive});

  final int id;
  final String plateNumber;
  final String vehicleType;
  final String qrId;
  final bool isActive;

  factory Vehicle.fromJson(Map<String, dynamic> json) => Vehicle(
        id: json['id'] as int,
        plateNumber: json['plate_number'] as String,
        vehicleType: json['vehicle_type'] as String,
        qrId: json['qr_id'] as String,
        isActive: json['is_active'] as bool? ?? true,
      );
}

class DispenseRecord {
  DispenseRecord({
    required this.id,
    required this.stationName,
    required this.fuelType,
    required this.litres,
    required this.dispensedAt,
    this.pricePerLitre,
  });

  final int id;
  final String stationName;
  final String fuelType;
  final double litres;
  final DateTime dispensedAt;
  final double? pricePerLitre;

  factory DispenseRecord.fromJson(Map<String, dynamic> json) => DispenseRecord(
        id: json['id'] as int,
        stationName: json['station_name'] as String? ?? '',
        fuelType: json['fuel_type'] as String,
        litres: double.parse(json['litres'].toString()),
        dispensedAt: DateTime.parse(json['dispensed_at'] as String),
        pricePerLitre: json['price_per_litre'] == null ? null : double.parse(json['price_per_litre'].toString()),
      );
}
