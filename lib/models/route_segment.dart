import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

class RouteSegment {
  final Point start;
  final Point end;
  final String startAddress;
  final String endAddress;
  final String startLabel;
  final String endLabel;
  final List<Point> polylinePoints;
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