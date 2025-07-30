import 'dart:async';
import 'package:flutter/material.dart';
import 'package:location/location.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

class DriverLocationProvider extends ChangeNotifier {
  Point? currentLocation;
  bool tracking = false;
  StreamSubscription<LocationData>? _locationSub;

  Future<void> startTracking() async {
    Location location = Location();
    bool serviceEnabled = await location.serviceEnabled();
    if (!serviceEnabled) serviceEnabled = await location.requestService();
    
    PermissionStatus permissionGranted = await location.hasPermission();
    if (permissionGranted == PermissionStatus.denied) {
      permissionGranted = await location.requestPermission();
    }
    
    if (permissionGranted == PermissionStatus.granted) {
      tracking = true;
      _locationSub = location.onLocationChanged.listen((loc) {
        currentLocation = Point(coordinates: Position(loc.longitude ?? -104.9, loc.latitude ?? 39.7));
        notifyListeners();
      });
    }
  }

  void stopTracking() {
    tracking = false;
    _locationSub?.cancel();
    notifyListeners();
  }

  @override
  void dispose() {
    _locationSub?.cancel();
    super.dispose();
  }
}