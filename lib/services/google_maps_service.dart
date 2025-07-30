import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import '../config/app_config.dart';

class MapboxService {
  static Future<Map<String, dynamic>?> getRoutePolyline(
      Point start, Point end) async {
    // Mapbox Directions API endpoint
    final accessToken = AppConfig.mapboxAccessToken; // <-- Add this to your config
    final url =
        'https://api.mapbox.com/directions/v5/mapbox/driving/${start.coordinates.lng},${start.coordinates.lat};${end.coordinates.lng},${end.coordinates.lat}?geometries=polyline&access_token=$accessToken';

    print("Requesting route from (${start.coordinates.lat}, ${start.coordinates.lng}) to (${end.coordinates.lat}, ${end.coordinates.lng})");
    print("URL: $url");

    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['routes'] != null && data['routes'].isNotEmpty) {
        final route = data['routes'][0];
        final polyline = decodePolyline(route['geometry']);
        final distance = route['distance'] * 1.0; // meters
        final duration = route['duration'] * 1.0; // seconds
        print("Route found: ${polyline.length} points, ${distance}m, ${duration}s");
        return {
          'polyline': polyline,
          'distance': distance,
          'duration': duration,
        };
      } else {
        print("No routes found in response");
      }
    } else {
      print("API request failed with status: ${response.statusCode}");
      print("Response body: ${response.body}");
    }
    return null;
  }

  // Decodes a Mapbox polyline string into a list of Points
  static List<Point> decodePolyline(String encoded) {
    List<Point> poly = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;
    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;
      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;
      // Mapbox expects (lng, lat) order for Point
      poly.add(Point(coordinates: Position(lng / 1E5, lat / 1E5)));
    }
    print("Decoded polyline with ${poly.length} points");
    if (poly.isNotEmpty) {
      print("First point: ${poly.first.coordinates.lat}, ${poly.first.coordinates.lng}");
      print("Last point: ${poly.last.coordinates.lat}, ${poly.last.coordinates.lng}");
    }
    return poly;
  }
}