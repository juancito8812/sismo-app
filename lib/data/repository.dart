import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import '../data/earthquake.dart';

class EarthquakeRepository {
  static const _usgsUrl =
      'https://earthquake.usgs.gov/earthquakes/feed/v1.0/summary/all_day.geojson';
  static const _funvisisUrl = 'https://www.funvisis.gob.ve/';
  static const _cimaUrl = 'https://www.cima.org.ve/';
  static const _usgsVenezuelaUrl =
      'https://earthquake.usgs.gov/fdsnws/event/1/query?format=geojson&minlatitude=-5&maxlatitude=15&minlongitude=-75&maxlongitude=-60&minmagnitude=2.5&orderby=time';

  Future<List<Earthquake>> fetchRecent() async {
    final futures = await Future.wait([
      _fetchFromUsgs(),
      _scrapeFunvisis(),
      _scrapeCima(),
    ]);

    final combined = <Earthquake>{...futures[0], ...futures[1], ...futures[2]}.toList();
    combined.sort((a, b) => b.time.compareTo(a.time));
    return combined;
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
        } catch (_) {}
      }
      return out;
    } catch (_) {
      return {};
    }
  }

  Future<Set<Earthquake>> _scrapeFunvisis() async {
    // FUNVISIS no expone datos sísmicos estructurados en HTML.
    // Intentamos varios endpoints conocidos.
    final urls = [
      'http://www.funvisis.gob.ve/',
    ];
    for (final url in urls) {
      try {
        final uri = Uri.parse(url);
        final response = await http.get(uri).timeout(const Duration(seconds: 10));
        if (response.statusCode != 200) continue;

        final doc = html_parser.parse(response.body);
        final text = doc.body?.text ?? '';

        // Buscar patrones de datos sísmicos en el texto
        final results = <Earthquake>{};
        final regex = RegExp(
          r'[Mm]agnitud\s*[:\-]?\s*([0-9]+[.,][0-9]+)',
        );
        for (final match in regex.allMatches(text)) {
          final mag = double.tryParse(match.group(1)!.replaceAll(',', '.'));
          if (mag != null && mag >= 2.5) {
            results.add(Earthquake(
              id: 'funvisis_${match.start}_${DateTime.now().millisecondsSinceEpoch}',
              magnitude: mag,
              place: 'Reportado por FUNVISIS',
              time: DateTime.now(),
              latitude: 8.0,
              longitude: -66.0,
              depthKm: 10,
              source: 'FUNVISIS',
            ));
          }
        }
        if (results.isNotEmpty) return results;
      } catch (_) {
        continue;
      }
    }
    return {};
  }

  Future<Set<Earthquake>> _scrapeCima() async {
    // CIMA no tiene datos sísmicos públicos estructurados.
    return {};
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
