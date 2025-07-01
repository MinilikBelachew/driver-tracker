import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum MapStyle {
  osmStandard(name: 'Standard', url: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png'),
  osmHot(name: 'Humanitarian', url: 'https://a.tile.openstreetmap.fr/hot/{z}/{x}/{y}.png'),
  stamenToner(name: 'Toner', url: 'https://stamen-tiles.a.ssl.fastly.net/toner/{z}/{x}/{y}.png');

  const MapStyle({required this.name, required this.url});
  final String name;
  final String url;
}

class MapStyleProvider with ChangeNotifier {
  MapStyle _currentMapStyle = MapStyle.osmStandard;
  MapStyle get currentMapStyle => _currentMapStyle;

  Future<void> loadMapStyle() async {
    final prefs = await SharedPreferences.getInstance();
    final savedStyleName = prefs.getString('mapStyle');
    if (savedStyleName != null) {
      _currentMapStyle = MapStyle.values.firstWhere(
        (style) => style.name == savedStyleName,
        orElse: () => MapStyle.osmStandard,
      );
    }
    notifyListeners();
  }

  void setMapStyle(MapStyle style) async {
    _currentMapStyle = style;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('mapStyle', style.name);
    notifyListeners();
  }
}