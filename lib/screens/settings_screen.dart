import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import '../data/earthquake.dart';
import '../data/local_db.dart';
import '../data/repository.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  double _minMagnitude = 3.0;
  int _pollInterval = 15;
  int _dateFilter = 0; // 0=todos, 1=24h, 2=7d, 3=30d
  String _sourceFilter = 'Todas';
  bool _exporting = false;
  bool _clearing = false;
  String? _exportPath;

  final _sources = ['Todas', 'USGS'];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ajustes'),
        backgroundColor: theme.colorScheme.inversePrimary,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // === Filtros ===
          Text('Filtros', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),

          // Magnitud mínima
          Text('Magnitud mínima: M${_minMagnitude.toStringAsFixed(1)}'),
          Slider(
            value: _minMagnitude,
            min: 1.0,
            max: 8.0,
            divisions: 14,
            label: 'M${_minMagnitude.toStringAsFixed(1)}',
            onChanged: (v) => setState(() => _minMagnitude = v),
          ),
          const SizedBox(height: 8),

          // Período
          Text('Período'),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 0, label: Text('Todo')),
              ButtonSegment(value: 1, label: Text('24h')),
              ButtonSegment(value: 2, label: Text('7d')),
              ButtonSegment(value: 3, label: Text('30d')),
            ],
            selected: {_dateFilter},
            onSelectionChanged: (v) => setState(() => _dateFilter = v.first),
          ),
          const SizedBox(height: 8),

          // Fuente
          DropdownButtonFormField<String>(
            value: _sourceFilter,
            decoration: const InputDecoration(
              labelText: 'Fuente',
              border: OutlineInputBorder(),
            ),
            items: _sources.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
            onChanged: (v) => setState(() => _sourceFilter = v ?? 'Todas'),
          ),
          const SizedBox(height: 8),

          // Aplicar filtros
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, _buildFilterMap()),
            icon: const Icon(Icons.filter_alt),
            label: const Text('Aplicar filtros'),
          ),

          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),

          // === Background ===
          Text('Background', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text('Intervalo de polling: $_pollInterval min'),
          Slider(
            value: _pollInterval.toDouble(),
            min: 5,
            max: 60,
            divisions: 11,
            label: '$_pollInterval min',
            onChanged: (v) => setState(() => _pollInterval = v.round()),
          ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),

          // === Exportar ===
          Text('Datos', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          if (_exportPath != null)
            Card(
              color: Colors.green.shade50,
              child: ListTile(
                leading: const Icon(Icons.check_circle, color: Colors.green),
                title: const Text('Exportado'),
                subtitle: Text(_exportPath!, style: const TextStyle(fontSize: 12)),
              ),
            ),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _exporting ? null : _exportCsv,
                  icon: _exporting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.file_download),
                  label: const Text('Exportar CSV'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _clearing ? null : _clearDb,
                  icon: _clearing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.delete_outline, color: Colors.red),
                  label: Text('Limpiar DB',
                      style: TextStyle(color: _clearing ? null : Colors.red)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Map<String, dynamic> _buildFilterMap() {
    final now = DateTime.now();
    DateTime? since;
    switch (_dateFilter) {
      case 1: since = now.subtract(const Duration(hours: 24));
      case 2: since = now.subtract(const Duration(days: 7));
      case 3: since = now.subtract(const Duration(days: 30));
    }
    return {
      'minMagnitude': _minMagnitude,
      'since': since?.millisecondsSinceEpoch,
      'source': _sourceFilter == 'Todas' ? null : _sourceFilter,
    };
  }

  Future<void> _exportCsv() async {
    setState(() => _exporting = true);
    try {
      final events = await LocalDb.instance.recent(limit: 10000);
      final rows = <List<String>>[
        ['ID', 'Magnitud', 'Lugar', 'Tiempo', 'Latitud', 'Longitud', 'Profundidad_km', 'Fuente', 'Notificado'],
      ];
      for (final e in events) {
        rows.add([
          e.id,
          e.magnitude.toStringAsFixed(2),
          e.place,
          e.time.toIso8601String(),
          e.latitude.toStringAsFixed(4),
          e.longitude.toStringAsFixed(4),
          e.depthKm.toStringAsFixed(1),
          e.source,
          e.notified.toString(),
        ]);
      }
      final csv = const ListToCsvConverter().convert(rows);
      final dir = await getApplicationDocumentsDirectory();
      final fileName = 'sismos_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.csv';
      final file = File('${dir.path}/$fileName');
      await file.writeAsString(csv);
      setState(() => _exportPath = file.path);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Exportado: $fileName')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al exportar: $e')),
        );
      }
    } finally {
      setState(() => _exporting = false);
    }
  }

  Future<void> _clearDb() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Limpiar historial'),
        content: const Text('¿Eliminar todos los eventos registrados?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Eliminar')),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _clearing = true);
    try {
      final db = await LocalDb.instance.database;
      await db.delete('events');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Historial limpiado')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      setState(() => _clearing = false);
    }
  }
}
