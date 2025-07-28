import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class RouteSegment {
  final LatLng start;
  final LatLng end;
  final String startAddress;
  final String endAddress;
  final String startLabel;
  final String endLabel;
  final List<LatLng> polylinePoints;
  final double distance;
  final double duration;
  final Color color;

  RouteSegment({
    required this.start,
    required this.end,
    required this.startAddress,
    required this.endAddress,
    required this.startLabel,
    required this.endLabel,
    required this.polylinePoints,
    required this.distance,
    required this.duration,
    required this.color,
  });
}