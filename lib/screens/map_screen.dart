import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';
import '../data/earthquake.dart';
import '../data/local_db.dart';
import 'event_detail.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  late final Future<List<Earthquake>> _events;

  // Clustering simple: agrupa eventos a menos de 1 grado
  List<Earthquake> _cluster(List<Earthquake> events) {
    if (events.length < 15) return events;
    final clustered = <Earthquake>[];
    final used = <int>{};
    for (var i = 0; i < events.length; i++) {
      if (used.contains(i)) continue;
      used.add(i);
      var sumMag = events[i].magnitude;
      var count = 1;
      double sumLat = events[i].latitude;
      double sumLon = events[i].longitude;
      for (var j = i + 1; j < events.length; j++) {
        if (used.contains(j)) continue;
        final dist = (events[i].latitude - events[j].latitude).abs() +
            (events[i].longitude - events[j].longitude).abs();
        if (dist < 1.0) {
          used.add(j);
          sumMag += events[j].magnitude;
          sumLat += events[j].latitude;
          sumLon += events[j].longitude;
          count++;
        }
      }
      clustered.add(Earthquake(
        id: 'cluster_$i',
        magnitude: count > 1 ? (sumMag / count) : events[i].magnitude,
        place: count > 1 ? '$count eventos' : events[i].place,
        time: events[i].time,
        latitude: sumLat / count,
        longitude: sumLon / count,
        depthKm: events[i].depthKm,
        source: events[i].source,
      ));
    }
    return clustered;
  }

  @override
  void initState() {
    super.initState();
    _events = LocalDb.instance.recent(limit: 200);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mapa de sismos'),
        backgroundColor: theme.colorScheme.inversePrimary,
      ),
      body: FutureBuilder<List<Earthquake>>(
        future: _events,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final events = snapshot.data ?? const <Earthquake>[];
          if (events.isEmpty) {
            return const Center(child: Text('Sin eventos registrados'));
          }

          final clustered = _cluster(events);

          // Calcular centro dinámico
          double avgLat2 = 0, avgLon2 = 0;
          for (final e in clustered) { avgLat2 += e.latitude; avgLon2 += e.longitude; }
          avgLat2 /= clustered.length;
          avgLon2 /= clustered.length;
          final center = LatLng(avgLat2, avgLon2);

          return Stack(
            children: [
              FlutterMap(
                options: MapOptions(center: center, zoom: 5.5),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.juancito8812.sismo_ve',
                  ),
                  MarkerLayer(
                    markers: clustered.map((e) {
                      return Marker(
                        point: LatLng(e.latitude, e.longitude),
                        width: _markerSize(e.magnitude) + 8,
                        height: _markerSize(e.magnitude) + 8,
                        child: GestureDetector(
                          onTap: () {
                            Navigator.push(context,
                              MaterialPageRoute(builder: (_) => EventDetailScreen(event: e)));
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: Earthquake.magnitudeColor(e.magnitude).withOpacity(0.85),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                              boxShadow: [BoxShadow(
                                color: Colors.black.withOpacity(0.3), blurRadius: 4, offset: const Offset(0, 2))],
                            ),
                            child: Center(
                              child: Text(e.place.contains('eventos') ? e.place.split(' ')[0] : '${e.magnitude.toStringAsFixed(1)}',
                                style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
              // Leyenda superpuesta
              Positioned(
                top: 8, right: 8,
                child: Card(
                  color: Colors.white.withOpacity(0.9),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Magnitud', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        _leg('M ≥ 6.0', const Color(0xFFE53935)),
                        _leg('M 5.0–5.9', const Color(0xFFFB8C00)),
                        _leg('M 4.0–4.9', const Color(0xFFFFC107)),
                        _leg('M < 4.0', const Color(0xFF43A047)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  double _markerSize(double mag) {
    if (mag >= 6.0) return 36;
    if (mag >= 5.0) return 30;
    if (mag >= 4.0) return 24;
    return 20;
  }

  Color _magnitudeColor(double mag) => Earthquake.magnitudeColor(mag);

  Widget _leg(String label, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 9)),
      ]),
    );
  }
}
