import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
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
        const SnackBar(content: Text('Reporte guardado localmente. ¡Gracias!')),
      );
      Navigator.pop(context);
    }
  }

  Future<void> _shareReport() async {
    final buf = StringBuffer();
    buf.writeln('📋 Reporte de sismo — SismoVE');
    buf.writeln('━━━━━━━━━━━━━━━━━━');
    if (widget.event != null) {
      buf.writeln('Sismo: M${widget.event!.magnitude.toStringAsFixed(1)} — ${widget.event!.place}');
    }
    buf.writeln('¿Lo sentiste? ${_felt ? "Sí" : "No"}');
    buf.writeln('Ubicación: $_location');
    buf.writeln('Intensidad: $_intensity/5');
    if (_damageCtrl.text.isNotEmpty) {
      buf.writeln('Daños: ${_damageCtrl.text}');
    }
    buf.writeln('━━━━━━━━━━━━━━━━━━');
    buf.writeln('App: SismoVE — Alertas sísmicas Venezuela');

    final msg = buf.toString();
    final uri = Uri.parse('https://wa.me/?text=${Uri.encodeComponent(msg)}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      final smsUri = Uri.parse('sms:?body=${Uri.encodeComponent(msg)}');
      if (await canLaunchUrl(smsUri)) {
        await launchUrl(smsUri);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se encontró app para compartir')),
        );
      }
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
            icon: const Icon(Icons.save),
            label: const Text('Guardar reporte local'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _shareReport,
            icon: const Icon(Icons.share),
            label: const Text('Compartir reporte'),
          ),
          const SizedBox(height: 8),
          Card(
            color: Colors.amber.shade50,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: Colors.amber.shade800),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Los reportes se guardan solo en tu dispositivo. '
                      'Usa "Compartir" para enviarlos a contactos o redes sociales.',
                      style: TextStyle(fontSize: 11, color: Colors.amber.shade900),
                    ),
                  ),
                ],
              ),
            ),
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
