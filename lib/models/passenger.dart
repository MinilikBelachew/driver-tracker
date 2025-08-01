import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

class Passenger {
  final String name;
  final double duration;
  final String earliestPickup;
  final String latestPickup;
  final String pickupAddress;
  final Point pickupLatLng;
  final String dropoffAddress;
  final Point dropoffLatLng;

  Passenger({
    required this.name,
    required this.duration,
    required this.earliestPickup,
    required this.latestPickup,
    required this.pickupAddress,
    required this.pickupLatLng,
    required this.dropoffAddress,
    required this.dropoffLatLng,
  });

  factory Passenger.fromJson(Map<String, dynamic> json) {
    return Passenger(
      name: json['name'] ?? '',
      duration: (json['estimatedDurationMin'] ?? 0).toDouble(),
      earliestPickup: json['earliestPickupTime'] ?? '',
      latestPickup: json['latestPickupTime'] ?? '',
      pickupAddress: _composeAddress(
        json['pickupStreetNumber'],
        json['pickupStreet'],
        json['pickupCity'],
        json['pickupZip'],
      ),
      pickupLatLng: Point(
        coordinates: Position(
          (json['pickupLng'] ?? 0).toDouble(),
          (json['pickupLat'] ?? 0).toDouble(),
        ),
      ),
      dropoffAddress: _composeAddress(
        json['dropoffStreetNumber'],
        json['dropoffStreet'],
        json['dropoffCity'],
        json['dropoffZip'],
      ),
      dropoffLatLng: Point(
        coordinates: Position(
          (json['dropoffLng'] ?? 0).toDouble(),
          (json['dropoffLat'] ?? 0).toDouble(),
        ),
      ),
    );
  }
}

// Helper to build address string
String _composeAddress(
  String? number,
  String? street,
  String? city,
  String? zip,
) {
  final parts = [
    if (number != null && number.isNotEmpty) number,
    if (street != null && street.isNotEmpty) street,
    if (city != null && city.isNotEmpty) city,
    if (zip != null && zip.isNotEmpty) zip,
  ];
  return parts.join(', ');
}