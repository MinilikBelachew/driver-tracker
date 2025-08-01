import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/passenger.dart';

class PassengerService {
  static Future<List<Passenger>> fetchPassengersForDriver(String driverId) async {
    final url = 'http://localhost:3000/api/v1/assignment/driversAssignment/$driverId';
    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final List<dynamic> assignments = json.decode(response.body);
      // Each assignment has a 'passenger' field
      return assignments
          .map((assignment) => Passenger.fromJson(assignment['passenger']))
          .toList();
    } else {
      throw Exception('Failed to load passengers');
    }
  }
}