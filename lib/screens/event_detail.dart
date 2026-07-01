import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:url_launcher/url_launcher.dart';
import '../data/earthquake.dart';

class EventDetailScreen extends StatelessWidget {
  final Earthquake event;

  const EventDetailScreen({super.key, required this.event});

  String _relativeTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 60) return '${diff.inMinutes} min atrás';
    if (diff.inHours < 24) return '${diff.inHours} h atrás';
    return '${diff.inDays} d atrás';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final timeFormat = DateFormat('dd/MM/yyyy HH:mm:ss');
    final lat = event.latitude;
    final lon = event.longitude;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle del sismo'),
        backgroundColor: theme.colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Compartir',
            onPressed: () {
              final url = Uri.parse('https://wa.me/?text=${Uri.encodeComponent(
                'SismoVE - Sismo detectado M${event.magnitude.toStringAsFixed(1)}\n'
                '${event.place}\n'
                '${timeFormat.format(event.time.toLocal())}\n'
                'Prof: ${event.depthKm.toStringAsFixed(1)} km\n'
                'Coord: ${lat.toStringAsFixed(4)}, ${lon.toStringAsFixed(4)}')}');
              launchUrl(url);
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Center(
              child: Column(
                children: [
                  Container(
                    width: 100, height: 100,
                    decoration: BoxDecoration(
                      color: Earthquake.magnitudeColor(event.magnitude),
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: Earthquake.magnitudeColor(event.magnitude).withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 4))],
                    ),
                    child: Center(
                      child: Text('M${event.magnitude.toStringAsFixed(1)}',
                        style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(event.place, textAlign: TextAlign.center, style: theme.textTheme.titleLarge),
                  const SizedBox(height: 4),
                  Text('${timeFormat.format(event.time.toLocal())} · ${_relativeTime(event.time)}',
                    style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Cards de info
            _infoCard(theme, Icons.straighten, 'Profundidad', '${event.depthKm.toStringAsFixed(1)} km', Colors.blue),
            _infoCard(theme, Icons.location_on, 'Coordenadas', '${lat.toStringAsFixed(4)}, ${lon.toStringAsFixed(4)}', Colors.teal),
            _infoCard(theme, Icons.source, 'Fuente', event.source, Colors.purple),
            _infoCard(theme, Icons.notifications_active, 'Notificado', event.notified == 1 ? 'Sí' : 'No', event.notified == 1 ? Colors.green : Colors.grey),
            const SizedBox(height: 16),

            // Mapa
            Text('Ubicación', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                height: 280,
                child: FlutterMap(
                  options: MapOptions(center: LatLng(lat, lon), zoom: 6),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.juancito8812.sismo_ve',
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: LatLng(lat, lon),
                          width: 40, height: 40,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Earthquake.magnitudeColor(event.magnitude),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 3),
                              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 6)],
                            ),
                            child: const Center(child: Icon(Icons.location_on, color: Colors.white, size: 20)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _infoCard(ThemeData theme, IconData icon, String label, String value, Color color) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          radius: 18,
          backgroundColor: color.withOpacity(0.15),
          child: Icon(icon, color: color, size: 18),
        ),
        title: Text(label, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        subtitle: Text(value, style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
        trailing: const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
      ),
    );
  }
}
