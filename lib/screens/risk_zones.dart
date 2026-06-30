import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RiskZonesScreen extends StatelessWidget {
  const RiskZonesScreen({super.key});

  static final _riskZones = [
    _RiskZone('Costa Caribe (tsunami)', LatLng(11.5, -69.0), 400, Colors.red.shade700, 'Zona de riesgo de tsunami. Si sientes un sismo fuerte en la costa, aléjate inmediatamente a tierras altas.'),
    _RiskZone('Falcon-Lara (sísmica)', LatLng(10.5, -70.0), 250, Colors.red.shade500, 'Zona de alta actividad sísmica histórica (terremotos de 1812, 1950).'),
    _RiskZone('Cordillera Andina', LatLng(8.5, -71.5), 300, Colors.orange.shade600, 'Zona de subducción activa. Sismos frecuentes de magnitud moderada.'),
    _RiskZone('Caracas - Litoral', LatLng(10.5, -66.9), 120, Colors.red.shade600, 'Falla de La Victoria. Alta densidad poblacional. Riesgo sísmico alto.'),
    _RiskZone('Sucre - Paria', LatLng(10.6, -63.0), 150, Colors.orange.shade500, 'Zona de convergencia Caribe-Suramérica. Sismicidad activa.'),
    _RiskZone('Los Andes (deslizamientos)', LatLng(8.0, -71.0), 200, Colors.brown, 'Zona de laderas inestables. Riesgo de deslizamientos inducidos por sismos.'),
    _RiskZone('Delta Amacuro', LatLng(9.0, -61.5), 150, Colors.green.shade700, 'Baja sismicidad. Riesgo principalmente por licuefacción de suelos.'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Zonas de riesgo'),
        backgroundColor: theme.colorScheme.inversePrimary,
      ),
      body: Column(
        children: [
          Expanded(
            flex: 2,
            child: FlutterMap(
              options: const MapOptions(
                center: LatLng(9.0, -66.0),
                zoom: 5,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.juancito8812.sismo_ve',
                ),
                MarkerLayer(
                  markers: _riskZones.map((z) => Marker(
                    point: z.center,
                    width: 30,
                    height: 30,
                    child: GestureDetector(
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            icon: Icon(Icons.warning, color: z.color),
                            title: Text(z.name),
                            content: Text(z.description),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cerrar')),
                            ],
                          ),
                        );
                      },
                      child: Icon(Icons.location_on, color: z.color, size: 28),
                    ),
                  )).toList(),
                ),
                // Círculos de riesgo
                /* Nota: flutter_map CircleLayer requiere datos de polígono, 
                   usamos markers como indicadores visuales */
              ],
            ),
          ),
          // Leyenda
          Container(
            padding: const EdgeInsets.all(12),
            color: theme.colorScheme.surfaceContainerHighest,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Leyenda de riesgo', style: theme.textTheme.titleSmall),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    _legend(Colors.red.shade700, 'Tsunami'),
                    _legend(Colors.red.shade500, 'Sísmico alto'),
                    _legend(Colors.orange.shade600, 'Sísmico moderado'),
                    _legend(Colors.brown, 'Deslizamiento'),
                    _legend(Colors.green.shade700, 'Bajo'),
                  ],
                ),
                const SizedBox(height: 4),
                Text('Toca los marcadores para más información.',
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
          // Lista de zonas
          Expanded(
            flex: 1,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: _riskZones.map((z) => ListTile(
                leading: Icon(Icons.circle, color: z.color, size: 16),
                title: Text(z.name, style: const TextStyle(fontSize: 14)),
                subtitle: Text(z.description.split('.')[0] + '.', style: const TextStyle(fontSize: 12)),
                dense: true,
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      icon: Icon(Icons.warning, color: z.color),
                      title: Text(z.name),
                      content: Text(z.description),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cerrar')),
                      ],
                    ),
                  );
                },
              )).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _legend(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.circle, color: color, size: 12),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}

class _RiskZone {
  final String name;
  final LatLng center;
  final double radiusKm;
  final Color color;
  final String description;
  const _RiskZone(this.name, this.center, this.radiusKm, this.color, this.description);
}
