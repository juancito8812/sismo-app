import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';
import '../data/earthquake.dart';
import '../data/local_db.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  late final Future<List<Earthquake>> _events;
  Earthquake? _selectedEvent;

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
                options: MapOptions(
                  initialCenter: center,
                  initialZoom: 5.5,
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.juancito8812.sismo_ve',
                  ),
                  MarkerLayer(
                    markers: clustered.map((e) {
                      final isSelected = _selectedEvent?.id == e.id;
                      return Marker(
                        point: LatLng(e.latitude, e.longitude),
                        width: _markerSize(e.magnitude) + (isSelected ? 8 : 0),
                        height: _markerSize(e.magnitude) + (isSelected ? 8 : 0),
                        child: GestureDetector(
                          onTap: () {
                            setState(() => _selectedEvent = isSelected ? null : e);
                            if (!isSelected) {
                              // center map on tap
                            }
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: Earthquake.magnitudeColor(e.magnitude).withValues(alpha: isSelected ? 1 : 0.85),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: isSelected ? 3 : 2),
                              boxShadow: [BoxShadow(
                                color: Colors.black.withValues(alpha: 0.3), blurRadius: 4, offset: const Offset(0, 2))],
                            ),
                            child: Center(
                              child: Text(e.place.contains('eventos') ? e.place.split(' ')[0] : e.magnitude.toStringAsFixed(1),
                                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
              // Leyenda
              Positioned(
                top: 8, left: 8,
                child: Card(
                  color: Colors.white.withOpacity(0.9),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Magnitud', style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold)),
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
              // Bottom sheet con evento seleccionado
              if (_selectedEvent != null)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: _MapBottomSheet(
                    event: _selectedEvent!,
                    onClose: () => setState(() => _selectedEvent = null),
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

class _MapBottomSheet extends StatelessWidget {
  final Earthquake event;
  final VoidCallback onClose;

  const _MapBottomSheet({required this.event, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8, offset: const Offset(0, -2))],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 8),
              decoration: BoxDecoration(color: theme.colorScheme.outlineVariant, borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Earthquake.magnitudeColor(event.magnitude),
                    radius: 18,
                    child: Text('M${event.magnitude.toStringAsFixed(1)}',
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(event.place, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodyMedium),
                        const SizedBox(height: 2),
                        Text('${event.depthKm.toStringAsFixed(1)} km · ${event.source}', style: theme.textTheme.bodySmall),
                      ],
                    ),
                  ),
                  TextButton.icon(onPressed: onClose, icon: const Icon(Icons.close, size: 16), label: const Text('Cerrar')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}