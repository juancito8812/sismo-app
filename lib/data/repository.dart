import 'dart:convert';
import 'package:http/http.dart' as http;
import '../data/earthquake.dart';

class EarthquakeRepository {
  static const _usgsUrl =
      'https://earthquake.usgs.gov/earthquakes/feed/v1.0/summary/all_day.geojson';
  static const _funvisisUrl = 'https://www.funvisis.gob.ve/';
  static const _cimaUrl = 'https://www.cima.org.ve/';

  Future<List<Earthquake>> fetchRecent() async {
    final usgs = await _fetchFromUsgs();
    final local = await _scrapeLocalSources();
    final combined = <Earthquake>{...usgs, ...local}.toList();
    combined.sort((a, b) => b.time.compareTo(a.time));
    return combined;
  }

  Future<Set<Earthquake>> _fetchFromUsgs() async {
    final uri = Uri.parse(_usgsUrl);
    final response = await http.get(uri).timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) {
      throw Exception('USGS HTTP ${response.statusCode}');
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final features = (data['features'] as List?) ?? const [];
    final out = <Earthquake>{};
    for (final feature in features) {
      try {
        final eq = Earthquake.fromJson(feature as Map<String, dynamic>);
        if (eq.magnitude >= 3 && _inVenezuelaArea(eq.latitude, eq.longitude)) {
          out.add(eq);
        }
      } catch (_) {
        // skip malformed entry
      }
    }
    return out;
  }

  Future<Set<Earthquake>> _scrapeLocalSources() async {
    // Placeholder de scraping para FUNVISIS / CIMA.
    // Ahora mismo no hace requests rìgidos; cuando definamos el HTML real,
    // parseamos con `html` y normalizamos a `Earthquake`.
    return <Earthquake>{};
  }

  bool _inVenezuelaArea(double lat, double lon) {
    // Bounding box ampliado para capturar eventos cercanos.
    return lat >= -5 && lat <= 15 && lon >= -75 && lon <= -60;
  }
}
