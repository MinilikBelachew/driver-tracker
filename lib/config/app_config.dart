import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  // static String get googleMapsApiKey => dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';
  static String get mapboxAccessToken => dotenv.env['MAPBOX_ACCESS_TOKEN'] ?? "pk.eyJ1IjoibWFtdXNoMTIzMyIsImEiOiJjbWQ5N3doMHYwNWJqMnFzNnl1eGR4djR2In0.VXyhfDyIx_4mClqyZ7FTpg";
}