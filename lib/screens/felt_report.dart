import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/earthquake.dart';

class FeltReportScreen extends StatefulWidget {
  final Earthquake? event;
  const FeltReportScreen({super.key, this.event});

  @override
  State<FeltReportScreen> createState() => _FeltReportScreenState();
}

class _FeltReportScreenState extends State<FeltReportScreen> {
  int _intensity = 3;
  String _location = 'Casa';
  final _damageCtrl = TextEditingController();
  bool _felt = true;
  final _locations = ['Casa', 'Trabajo', 'Calle', 'Vehículo', 'Edificio alto', 'Playa', 'Montaña', 'Otro'];

  @override
  void dispose() {
    _damageCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final prefs = await SharedPreferences.getInstance();
    final damage = _damageCtrl.text.replaceAll('|', ' ');
    final reports = prefs.getStringList('felt_reports') ?? [];
    reports.add([
      DateTime.now().toIso8601String(),
      widget.event?.id ?? 'desconocido',
      widget.event?.magnitude.toString() ?? 'N/A',
      _location,
      _felt.toString(),
      _intensity.toString(),
      damage,
    ].join('|'));
    await prefs.setStringList('felt_reports', reports);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reporte enviado. ¡Gracias!')),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final event = widget.event;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reportar sismo'),
        backgroundColor: theme.colorScheme.inversePrimary,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (event != null) ...[
            Card(
              color: Colors.red.shade50,
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Earthquake.magnitudeColor(event.magnitude),
                  child: Text('M${event.magnitude.toStringAsFixed(1)}',
                      style: const TextStyle(color: Colors.white, fontSize: 12)),
                ),
                title: Text(event.place),
                subtitle: Text('${event.time.toLocal()}'),
              ),
            ),
            const SizedBox(height: 16),
          ],
          Text('¿Sentiste este sismo?', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: true, label: Text('Sí')),
              ButtonSegment(value: false, label: Text('No')),
            ],
            selected: {_felt},
            onSelectionChanged: (v) => setState(() => _felt = v.first),
          ),
          const SizedBox(height: 16),

          Text('¿Dónde estabas?', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _location,
            items: _locations.map((l) => DropdownMenuItem(value: l, child: Text(l))).toList(),
            onChanged: (v) => setState(() => _location = v ?? 'Casa'),
            decoration: const InputDecoration(border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),

          Text('Intensidad percibida', style: theme.textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(_intensityDesc(), style: theme.textTheme.bodySmall),
          Slider(
            value: _intensity.toDouble(), min: 1, max: 5, divisions: 4,
            label: _intensity.toString(),
            onChanged: (v) => setState(() => _intensity = v.round()),
          ),
          const SizedBox(height: 16),

          TextField(
            controller: _damageCtrl,
            decoration: const InputDecoration(
              labelText: '¿Observaste daños? (opcional)',
              hintText: 'Ej: cuadro cayó, grieta leve en pared...',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 24),

          FilledButton.icon(
            onPressed: _submit,
            icon: const Icon(Icons.send),
            label: const Text('Enviar reporte'),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  String _intensityDesc() {
    switch (_intensity) {
      case 1: return '1 — Muy leve (apenas se sintió)';
      case 2: return '2 — Leve (como un camión pasando)';
      case 3: return '3 — Moderado (se movieron objetos)';
      case 4: return '4 — Fuerte (dificultad para mantenerse en pie)';
      case 5: return '5 — Muy fuerte (daños estructurales)';
      default: return '';
    }
  }
}
