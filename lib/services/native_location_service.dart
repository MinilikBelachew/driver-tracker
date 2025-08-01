import 'package:flutter/services.dart';

class NativeLocationService {
  static const _methodChannel = MethodChannel('com.example.driver/location_service');
  static const _eventChannel = EventChannel('com.example.driver/location_events');

  static Stream<Map<dynamic, dynamic>> get locationStream {
    return _eventChannel
        .receiveBroadcastStream()
        .map((event) => event as Map<dynamic, dynamic>)
        .handleError((error) {
      print('Error in location stream: $error');
    });
  }


  static Stream<Map<dynamic, dynamic>>? _locationStream;

  static Future<void> startService({
    required String token,
    required String driverId,
    required String serverUrl,
  }) async {
    try {
      await _methodChannel.invokeMethod('startService', {
        'token': token,
        'driverId': driverId,
        'serverUrl': serverUrl,
      });
    } on PlatformException catch (e) {
      print("Failed to start service: '${e.message}'.");
      rethrow;
    }
  }

  static Future<void> stopService() async {
    try {
      await _methodChannel.invokeMethod('stopService');
    } on PlatformException catch (e) {
      print("Failed to stop service: '${e.message}'.");
      rethrow;
    }
  }

  // Updated getter name to match what's being called in TrackingPage
  static Stream<Map<dynamic, dynamic>> get getLocationStream {
    _locationStream ??= _eventChannel.receiveBroadcastStream().cast<Map<dynamic, dynamic>>();
    return _locationStream!;
  }
}