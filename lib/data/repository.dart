import 'dart:convert';
import 'package:http/http.dart' as http;
import '../data/earthquake.dart';

class EarthquakeRepository {
  static const _usgsVenezuelaUrl =
      'https://earthquake.usgs.gov/fdsnws/event/1/query?format=geojson&minlatitude=-5&maxlatitude=15&minlongitude=-75&maxlongitude=-60&minmagnitude=2.5&orderby=time';

  Future<List<Earthquake>> fetchRecent() async {
    final events = await _fetchFromUsgs();
    return events.toList()..sort((a, b) => b.time.compareTo(a.time));
  }

  Future<Set<Earthquake>> _fetchFromUsgs() async {
    try {
      final uri = Uri.parse(_usgsVenezuelaUrl);
      final response = await http.get(uri).timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) return {};

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final features = (data['features'] as List?) ?? const [];
      final out = <Earthquake>{};
      for (final feature in features) {
        try {
          final eq = Earthquake.fromJson(feature as Map<String, dynamic>);
          if (_inVenezuelaArea(eq.latitude, eq.longitude)) {
            out.add(eq);
          }
        } catch (e) {
          // ignore: avoid_print
          print('[repository] skip malformed feature: $e');
        }
      }
      return out;
    } catch (e) {
      // ignore: avoid_print
      print('[repository] USGS fetch error: $e');
      return {};
    }
  }

  /// Seed histórico: descarga eventos USGS Venezuela desde una fecha
  Future<List<Earthquake>> fetchHistorical({required DateTime since, DateTime? until}) async {
    final untilStr = until != null
        ? '&endtime=${until.toIso8601String().split('T')[0]}'
        : '';
    final url =
        'https://earthquake.usgs.gov/fdsnws/event/1/query?format=geojson'
        '&starttime=${since.toIso8601String().split('T')[0]}$untilStr'
        '&minlatitude=-5&maxlatitude=15&minlongitude=-75&maxlongitude=-60'
        '&minmagnitude=2.5&orderby=time&limit=20000';

    try {
      final uri = Uri.parse(url);
      final response = await http.get(uri).timeout(const Duration(seconds: 30));
      if (response.statusCode != 200) return [];

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final features = (data['features'] as List?) ?? [];
      final out = <Earthquake>[];
      for (final feature in features) {
        try {
          final eq = Earthquake.fromJson(feature as Map<String, dynamic>);
          if (_inVenezuelaArea(eq.latitude, eq.longitude)) {
            out.add(eq);
          }
        } catch (_) {}
      }
      return out;
    } catch (_) {
      return [];
    }
  }

  bool _inVenezuelaArea(double lat, double lon) {
    return lat >= -5 && lat <= 15 && lon >= -75 && lon <= -60;
  }
}
