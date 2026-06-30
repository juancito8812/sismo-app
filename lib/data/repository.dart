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
    try {
      final uri = Uri.parse(_funvisisUrl);
      final response = await http.get(uri).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) return {};

      final doc = html_parser.parse(response.body);
      final out = <Earthquake>{};

      // Buscar tablas o listas con datos sísmicos
      final tables = doc.querySelectorAll('table');
      for (final table in tables) {
        final rows = table.querySelectorAll('tr');
        for (final row in rows) {
          final cells = row.querySelectorAll('td');
          if (cells.length >= 5) {
            try {
              final mag = double.tryParse(cells[0].text.trim());
              final place = cells[1].text.trim();
              final lat = double.tryParse(cells[2].text.trim());
              final lon = double.tryParse(cells[3].text.trim());
              final depth = double.tryParse(cells[4].text.trim());
              if (mag != null && lat != null && lon != null) {
                out.add(Earthquake(
                  id: 'funvisis_${lat}_${lon}_${DateTime.now().millisecondsSinceEpoch}',
                  magnitude: mag,
                  place: place.isNotEmpty ? place : 'Venezuela (FUNVISIS)',
                  time: DateTime.now(),
                  latitude: lat,
                  longitude: lon,
                  depthKm: depth ?? 10,
                  source: 'FUNVISIS',
                ));
              }
            } catch (_) {}
          }
        }
      }

      // Buscar <p> o <div> con datos de magnitud
      if (out.isEmpty) {
        final body = doc.body?.text ?? '';
        final magRegex = RegExp(r'[Mm]agnitud[^0-9]*([0-9]+\.[0-9]+)');
        final latRegex = RegExp(r'[Ll]atitud[^0-9\-]*([\-0-9]+\.[0-9]+)');
        final lonRegex = RegExp(r'[Ll]ongitud[^0-9\-]*([\-0-9]+\.[0-9]+)');

        final magMatch = magRegex.firstMatch(body);
        final latMatch = latRegex.firstMatch(body);
        final lonMatch = lonRegex.firstMatch(body);

        if (magMatch != null && latMatch != null && lonMatch != null) {
          final mag = double.tryParse(magMatch.group(1)!);
          final lat = double.tryParse(latMatch.group(1)!);
          final lon = double.tryParse(lonMatch.group(1)!);
          if (mag != null && lat != null && lon != null) {
            out.add(Earthquake(
              id: 'funvisis_scrape_${DateTime.now().millisecondsSinceEpoch}',
              magnitude: mag,
              place: 'Venezuela (FUNVISIS)',
              time: DateTime.now(),
              latitude: lat,
              longitude: lon,
              depthKm: 10,
              source: 'FUNVISIS',
            ));
          }
        }
      }

      return out;
    } catch (_) {
      return {};
    }
  }

  Future<Set<Earthquake>> _scrapeCima() async {
    try {
      final uri = Uri.parse(_cimaUrl);
      final response = await http.get(uri).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) return {};

      final doc = html_parser.parse(response.body);
      final body = doc.body?.text ?? '';
      final out = <Earthquake>{};

      // Buscar patrones de datos sísmicos en el texto
      final regex = RegExp(
        r'([Mm])?([0-9]+\.[0-9]+)\s*.*?[Vv]enezuela',
      );
      for (final match in regex.allMatches(body)) {
        final mag = double.tryParse(match.group(2) ?? '');
        if (mag != null && mag >= 2.5) {
          out.add(Earthquake(
            id: 'cima_scrape_${match.start}_${DateTime.now().millisecondsSinceEpoch}',
            magnitude: mag,
            place: 'Venezuela (CIMA)',
            time: DateTime.now(),
            latitude: 8.0,
            longitude: -66.0,
            depthKm: 10,
            source: 'CIMA',
          ));
        }
      }

      return out;
    } catch (_) {
      return {};
    }
  }

  bool _inVenezuelaArea(double lat, double lon) {
    return lat >= -5 && lat <= 15 && lon >= -75 && lon <= -60;
  }
}
