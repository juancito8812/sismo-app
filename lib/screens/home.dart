import 'package:flutter/material.dart';
import '../data/local_db.dart';
import '../data/earthquake.dart';
import '../services/background_poller.dart';
import 'event_detail.dart';
import 'map_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<List<Earthquake>> _future;
  int _newCount = 0;

  // Filtros
  double _minMag = 0;
  int _dateRange = 0; // 0=todo, 1=24h, 2=7d, 3=30d
  String _source = 'Todas';

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Earthquake>> _load() async {
    await _initBackground();
    int? sinceMs;
    final now = DateTime.now();
    switch (_dateRange) {
      case 1: sinceMs = now.subtract(const Duration(hours: 24)).millisecondsSinceEpoch;
      case 2: sinceMs = now.subtract(const Duration(days: 7)).millisecondsSinceEpoch;
      case 3: sinceMs = now.subtract(const Duration(days: 30)).millisecondsSinceEpoch;
      default: sinceMs = null;
    }

    final items = await LocalDb.instance.queryFiltered(
      minMagnitude: _minMag > 0 ? _minMag : null,
      sinceEpochMs: sinceMs,
      source: _source == 'Todas' ? null : _source,
      limit: 200,
    );
    final count = await LocalDb.instance.unnotifiedCount();
    if (mounted) setState(() => _newCount = count);
    return items;
  }

  Future<void> _refresh() async {
    final latest = await _load();
    if (!mounted) return;
    setState(() => _future = Future.value(latest));
  }

  Future<void> _initBackground() async {}

  void _openDetail(Earthquake e) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EventDetailScreen(event: e)),
    );
  }

  void _openMap() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MapScreen()),
    );
  }

  Future<void> _openSettings() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
    if (result != null) {
      setState(() {
        _minMag = (result['minMagnitude'] as num?)?.toDouble() ?? 0;
        final sinceMs = result['since'] as int?;
        if (sinceMs != null) {
          final now = DateTime.now().millisecondsSinceEpoch;
          final diff = now - sinceMs;
          if (diff <= const Duration(hours: 24).inMilliseconds) _dateRange = 1;
          else if (diff <= const Duration(days: 7).inMilliseconds) _dateRange = 2;
          else if (diff <= const Duration(days: 30).inMilliseconds) _dateRange = 3;
        }
        _source = result['source'] as String? ?? 'Todas';
      });
      _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('SismoVE'),
        backgroundColor: theme.colorScheme.inversePrimary,
        actions: [
          if (_newCount > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Center(
                child: Chip(
                  visualDensity: VisualDensity.compact,
                  label: Text('$_newCount nuevo(s)'),
                  onDeleted: () => setState(() => _newCount = 0),
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.map),
            tooltip: 'Mapa',
            onPressed: _openMap,
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Ajustes',
            onPressed: _openSettings,
          ),
        ],
      ),
      body: Column(
        children: [
          // Filtros inline
          _buildFilterBar(theme),
          // Lista de eventos
          Expanded(
            child: FutureBuilder<List<Earthquake>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                final items = snapshot.data ?? const <Earthquake>[];
                if (items.isEmpty) {
                  return const Center(child: Text('Sin eventos registrados'));
                }
                return RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final e = items[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Earthquake.magnitudeColor(e.magnitude),
                          child: Text(
                            'M${e.magnitude.toStringAsFixed(1)}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(e.place, maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text(
                          '${_formatTime(e.time)} · ${e.depthKm.toStringAsFixed(1)} km · ${e.source}',
                        ),
                        trailing: e.notified == 0
                            ? const Icon(Icons.fiber_new, color: Colors.red, size: 18)
                            : null,
                        onTap: () => _openDetail(e),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      color: theme.colorScheme.surfaceContainerHighest,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _filterChip('M ≥ ${_minMag.toStringAsFixed(0)}', _minMag > 0, () {
              setState(() => _minMag = _minMag > 0 ? 0 : 3);
              _refresh();
            }),
            const SizedBox(width: 6),
            _filterChip(
              ['Todo', '24h', '7d', '30d'][_dateRange],
              _dateRange > 0,
              () {
                setState(() => _dateRange = _dateRange > 0 ? 0 : 1);
                _refresh();
              },
            ),
            const SizedBox(width: 6),
            _filterChip(_source, _source != 'Todas', () {
              setState(() => _source = _source == 'Todas' ? 'USGS' : 'Todas');
              _refresh();
            }),
          ],
        ),
      ),
    );
  }

  Widget _filterChip(String label, bool active, VoidCallback onTap) {
    return FilterChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      selected: active,
      onSelected: (_) => onTap(),
      visualDensity: VisualDensity.compact,
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inMinutes < 60) return '${diff.inMinutes} min';
    if (diff.inHours < 24) return '${diff.inHours} h';
    return '${diff.inDays} d';
  }
}
