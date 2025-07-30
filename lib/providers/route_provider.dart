import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import '../models/route_segment.dart';
import '../models/passenger.dart';
import '../services/google_maps_service.dart';

class RouteProvider extends ChangeNotifier {
  List<RouteSegment> segments = [];
  bool loading = true;
  double totalDistance = 0;
  double totalDuration = 0;
  
  Future<void> buildCompleteRoute(List<Passenger> passengers, Point driverLocation) async {
    loading = true;
    notifyListeners();
    
    segments = [];
    totalDistance = 0;
    totalDuration = 0;
    
    print("Building route for ${passengers.length} passengers");
    print("Driver location: ${driverLocation.coordinates.lat}, ${driverLocation.coordinates.lng}");
    
    List<Passenger> sorted = [...passengers];
    sorted.sort((a, b) => a.earliestPickup.compareTo(b.earliestPickup));
    
    // Driver to first pickup
    final driverToFirstPickup = await MapboxService.getRoutePolyline(
      driverLocation, 
      sorted[0].pickupLatLng,
    );
    
    if (driverToFirstPickup != null) {
      print("Driver to first pickup route found: ${driverToFirstPickup['polyline'].length} points");
      segments.add(RouteSegment(
        start: driverLocation,
        end: sorted[0].pickupLatLng,
        startAddress: "Current Location",
        endAddress: sorted[0].pickupAddress,
        startLabel: "Driver",
        endLabel: "Pickup:  {sorted[0].name}",
        polylinePoints: driverToFirstPickup['polyline'],
        distance: driverToFirstPickup['distance'],
        duration: driverToFirstPickup['duration'],
        color: Colors.blue,
      ));
      
      totalDistance += driverToFirstPickup['distance'];
      totalDuration += driverToFirstPickup['duration'];
    } else {
      print("Failed to get driver to first pickup route");
    }
    
    // Add pickup to dropoff and dropoff to next pickup segments
    for (int i = 0; i < sorted.length; i++) {
      // Pickup to dropoff
      final pickupToDropoff = await MapboxService.getRoutePolyline(
        sorted[i].pickupLatLng,
        sorted[i].dropoffLatLng,
      );
      
      if (pickupToDropoff != null) {
        segments.add(RouteSegment(
          start: sorted[i].pickupLatLng,
          end: sorted[i].dropoffLatLng,
          startAddress: sorted[i].pickupAddress,
          endAddress: sorted[i].dropoffAddress,
          startLabel: "Pickup:  {sorted[i].name}",
          endLabel: "Dropoff:  {sorted[i].name}",
          polylinePoints: pickupToDropoff['polyline'],
          distance: pickupToDropoff['distance'],
          duration: pickupToDropoff['duration'],
          color: Colors.orange,
        ));
        
        totalDistance += pickupToDropoff['distance'];
        totalDuration += pickupToDropoff['duration'];
      }
      
      // If there's a next passenger, add dropoff to next pickup segment
      if (i < sorted.length - 1) {
        final dropoffToNextPickup = await MapboxService.getRoutePolyline(
          sorted[i].dropoffLatLng,
          sorted[i + 1].pickupLatLng,
        );
        
        if (dropoffToNextPickup != null) {
          segments.add(RouteSegment(
            start: sorted[i].dropoffLatLng,
            end: sorted[i + 1].pickupLatLng,
            startAddress: sorted[i].dropoffAddress,
            endAddress: sorted[i + 1].pickupAddress,
            startLabel: "Dropoff:  {sorted[i].name}",
            endLabel: "Pickup:  {sorted[i + 1].name}",
            polylinePoints: dropoffToNextPickup['polyline'],
            distance: dropoffToNextPickup['distance'],
            duration: dropoffToNextPickup['duration'],
            color: Colors.purple,
          ));
          
          totalDistance += dropoffToNextPickup['distance'];
          totalDuration += dropoffToNextPickup['duration'];
        }
      }
    }
    
    loading = false;
    print("Route building complete. Total segments: ${segments.length}");
    print("Total distance: ${totalDistance}m, Total duration: ${totalDuration}s");
    notifyListeners();
  }
}