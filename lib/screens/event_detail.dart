import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';
import '../data/earthquake.dart';

class EventDetailScreen extends StatelessWidget {
  final Earthquake event;

  const EventDetailScreen({super.key, required this.event});

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
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: magnitud + ubicación
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 48,
                    backgroundColor: Earthquake.magnitudeColor(event.magnitude),
                    child: Text(
                      'M${event.magnitude.toStringAsFixed(1)}',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    event.place,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    timeFormat.format(event.time.toLocal()),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),

            // Detalles en tarjetas
            _infoRow(theme, Icons.straighten, 'Profundidad',
                '${event.depthKm.toStringAsFixed(1)} km'),
            _infoRow(theme, Icons.location_on, 'Coordenadas',
                '${lat.toStringAsFixed(4)}, ${lon.toStringAsFixed(4)}'),
            _infoRow(theme, Icons.source, 'Fuente', event.source),
            _infoRow(theme, Icons.notifications_active,
                'Notificado', event.notified == 1 ? 'Sí' : 'No'),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),

            // Mapa pequeño
            Text('Ubicación', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            SizedBox(
              height: 300,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: FlutterMap(
                  options: MapOptions(
                    center: LatLng(lat, lon),
                    zoom: 6,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName:
                          'com.juancito8812.sismo_ve',
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: LatLng(lat, lon),
                          width: 40,
                          height: 40,
                          child: Icon(
                            Icons.circle,
                            color: Earthquake.magnitudeColor(event.magnitude),
                            size: 32,
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

  Widget _infoRow(ThemeData theme, IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: theme.colorScheme.primary, size: 20),
          const SizedBox(width: 12),
          Text(label, style: theme.textTheme.bodyMedium),
          const Spacer(),
          Text(value,
              style: theme.textTheme.bodyLarge
                  ?.copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Color _magnitudeColor(double mag) => Earthquake.magnitudeColor(mag);
}
