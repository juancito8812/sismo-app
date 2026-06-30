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

          // Calcular centro (Venezuela)
          const center = LatLng(8.0, -66.0);

          return FlutterMap(
            options: MapOptions(
              center: center,
              zoom: 5.5,
              onTap: (tapPos, latlng) {},
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName:
                    'com.juancito8812.venezuela_sismos_app',
              ),
              MarkerLayer(
                markers: events.map((e) {
                  return Marker(
                    point: LatLng(e.latitude, e.longitude),
                    width: _markerSize(e.magnitude) + 8,
                    height: _markerSize(e.magnitude) + 8,
                    child: GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => EventDetailScreen(event: e),
                          ),
                        );
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: _magnitudeColor(e.magnitude).withOpacity(0.85),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white,
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            '${e.magnitude.toStringAsFixed(1)}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
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

  Color _magnitudeColor(double mag) {
    if (mag >= 6.0) return Colors.red;
    if (mag >= 5.0) return Colors.orange;
    if (mag >= 4.0) return Colors.amber;
    return Colors.green;
  }
}
