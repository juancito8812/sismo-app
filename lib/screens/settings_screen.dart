import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
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
  int _dateFilter = 0;
  String _sourceFilter = 'Todas';
  bool _exporting = false;
  bool _clearing = false;
  bool _seeding = false;
  bool _checking = false;
  String? _updateInfo;
  String? _updateUrl;
  String? _exportPath;
  int _seededCount = 0;

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
          Text('Filtros', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          Text('Magnitud mínima: M${_minMagnitude.toStringAsFixed(1)}'),
          Slider(
            value: _minMagnitude, min: 1.0, max: 8.0, divisions: 14,
            label: 'M${_minMagnitude.toStringAsFixed(1)}',
            onChanged: (v) => setState(() => _minMagnitude = v),
          ),
          const SizedBox(height: 8),
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
          DropdownButtonFormField<String>(
            value: _sourceFilter,
            decoration: const InputDecoration(labelText: 'Fuente', border: OutlineInputBorder()),
            items: _sources.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
            onChanged: (v) => setState(() => _sourceFilter = v ?? 'Todas'),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, _buildFilterMap()),
            icon: const Icon(Icons.filter_alt),
            label: const Text('Aplicar filtros'),
          ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),

          Text('Background', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text('Intervalo de polling: $_pollInterval min'),
          Slider(
            value: _pollInterval.toDouble(), min: 5, max: 60, divisions: 11,
            label: '$_pollInterval min',
            onChanged: (v) => setState(() => _pollInterval = v.round()),
          ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),

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
          if (_seededCount > 0)
            Card(
              color: Colors.blue.shade50,
              child: ListTile(
                leading: const Icon(Icons.history, color: Colors.blue),
                title: Text('$_seededCount eventos históricos (Ene–Jun 2026)'),
              ),
            ),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _exporting ? null : _exportCsv,
                  icon: _exporting
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.file_download),
                  label: const Text('Exportar CSV'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _clearing ? null : _clearDb,
                  icon: _clearing
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.delete_outline, color: Colors.red),
                  label: Text('Limpiar DB', style: TextStyle(color: _clearing ? null : Colors.red)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _seeding ? null : _seedHistorical,
            icon: _seeding
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.cloud_download),
            label: Text(_seeding ? 'Descargando...' : 'Seed datos históricos (2026)'),
          ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),
          Text('Actualizaciones', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          if (_updateInfo != null)
            Card(
              color: _updateInfo!.contains('disponible') ? Colors.green.shade50 : Colors.grey.shade100,
              child: ListTile(
                leading: Icon(
                  _updateInfo!.contains('disponible') ? Icons.system_update : Icons.check_circle,
                  color: _updateInfo!.contains('disponible') ? Colors.green : Colors.grey,
                ),
                title: Text(_updateInfo!),
                subtitle: _updateUrl != null ? Text('v1.0.0 → $_updateInfo') : null,
                trailing: _updateUrl != null
                    ? ElevatedButton(
                        onPressed: () => launchUrl(Uri.parse(_updateUrl!)),
                        child: const Text('Descargar'),
                      )
                    : null,
              ),
            ),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _checking ? null : _checkForUpdate,
                  icon: _checking
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.system_update),
                  label: Text(_checking ? 'Buscando...' : 'Buscar actualización'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Center(
            child: Text('Versión: 1.0.0 (build ${_buildNumber})',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
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
      final events = await LocalDb.instance.recent();
      final rows = <List<String>>[
        ['ID', 'Magnitud', 'Lugar', 'Tiempo', 'Latitud', 'Longitud', 'Profundidad_km', 'Fuente', 'Notificado'],
      ];
      for (final e in events) {
        rows.add([e.id, e.magnitude.toStringAsFixed(2), e.place, e.time.toIso8601String(),
          e.latitude.toStringAsFixed(4), e.longitude.toStringAsFixed(4),
          e.depthKm.toStringAsFixed(1), e.source, e.notified.toString()]);
      }
      final csv = const ListToCsvConverter().convert(rows);
      final dir = await getApplicationDocumentsDirectory();
      final fileName = 'sismos_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.csv';
      final file = File('${dir.path}/$fileName');
      await file.writeAsString(csv);
      setState(() => _exportPath = file.path);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Exportado: $fileName')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
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
      setState(() => _seededCount = 0);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Historial limpiado')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      setState(() => _clearing = false);
    }
  }

  Future<void> _seedHistorical() async {
    setState(() => _seeding = true);
    try {
      final repo = EarthquakeRepository();
      final events = await repo.fetchHistorical(
        since: DateTime(2026, 1, 1),
        until: DateTime(2026, 6, 30),
      );
      final db = LocalDb.instance;
      for (final eq in events) {
        await db.insertOrUpdate(eq);
      }
      setState(() => _seededCount = events.length);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${events.length} eventos históricos cargados')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      setState(() => _seeding = false);
    }
  }

  int get _buildNumber => 13;

  Future<void> _checkForUpdate() async {
    setState(() { _checking = true; _updateInfo = null; _updateUrl = null; });
    try {
      final uri = Uri.parse('https://api.github.com/repos/juancito8812/sismo-app/releases/latest');
      final response = await http.get(uri, headers: {'Accept': 'application/vnd.github+json'})
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) {
        setState(() => _updateInfo = 'Error al consultar actualizaciones');
        return;
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final tag = data['tag_name'] as String? ?? '';
      final assets = data['assets'] as List? ?? [];
      String? apkUrl;
      for (final a in assets) {
        final name = a['name'] as String? ?? '';
        if (name.endsWith('.apk')) {
          apkUrl = a['browser_download_url'] as String?;
          break;
        }
      }

      // Extraer número de versión del tag (ej: "v13" → 13)
      final versionNum = int.tryParse(tag.replaceAll(RegExp(r'[^\d]'), ''));
      if (versionNum != null && versionNum > _buildNumber) {
        setState(() {
          _updateInfo = 'Actualización disponible: $tag';
          _updateUrl = apkUrl;
        });
      } else {
        setState(() => _updateInfo = 'Ya tienes la última versión ($tag)');
      }
    } catch (e) {
      setState(() => _updateInfo = 'Error: $e');
    } finally {
      setState(() => _checking = false);
    }
  }
}
