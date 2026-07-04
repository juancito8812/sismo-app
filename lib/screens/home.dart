import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../data/local_db.dart';
import '../data/earthquake.dart';
import 'event_detail.dart';
import 'map_screen.dart';
import 'settings_screen.dart';
import 'safety_guide.dart';
import 'emergency_kit.dart';
import 'emergency_contacts.dart';
import 'torch_sos.dart';
import 'family_plan.dart';
import 'felt_report.dart';
import 'first_aid.dart';
import 'risk_zones.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<List<Earthquake>> _future;
  int _newCount = 0;
  double _minMag = 0;
  int _dateRange = 0;
  String _source = 'Todas';

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Earthquake>> _load() async {
    int? sinceMs;
    final now = DateTime.now();
    switch (_dateRange) {
      case 1: sinceMs = now.subtract(const Duration(hours: 24)).millisecondsSinceEpoch;
      case 2: sinceMs = now.subtract(const Duration(days: 7)).millisecondsSinceEpoch;
      case 3: sinceMs = now.subtract(const Duration(days: 30)).millisecondsSinceEpoch;
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

  void _openDetail(Earthquake e) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => EventDetailScreen(event: e)));
  }

  void _openMap() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const MapScreen()));
  }

  void _openPage(Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  Future<void> _openSettings() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context, MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
    if (result != null && mounted) {
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

  void _dismissNews() {
    setState(() => _newCount = 0);
    LocalDb.instance.clearNotified();
  }

  void _openActions() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            _prepButton(Icons.map, 'Mapa', () { Navigator.pop(ctx); _openPage(const MapScreen()); }),
            _prepButton(Icons.settings, 'Ajustes', () { Navigator.pop(ctx); _openSettings(); }),
            _prepButton(Icons.healing, 'Guía', () { Navigator.pop(ctx); _openPage(const SafetyGuideScreen()); }),
            _prepButton(Icons.emergency, 'Kit', () { Navigator.pop(ctx); _openPage(const EmergencyKitScreen()); }),
            _prepButton(Icons.phone, 'Contactos', () { Navigator.pop(ctx); _openPage(const EmergencyContactsScreen()); }),
            _prepButton(Icons.flash_on, 'SOS', () { Navigator.pop(ctx); _openPage(const TorchSosScreen()); }),
            _prepButton(Icons.people, 'Familia', () { Navigator.pop(ctx); _openPage(const FamilyPlanScreen()); }),
            _prepButton(Icons.report, 'Reportar', () { Navigator.pop(ctx); _openPage(const FeltReportScreen()); }),
            _prepButton(Icons.medical_services, 'Auxilios', () { Navigator.pop(ctx); _openPage(const FirstAidScreen()); }),
            _prepButton(Icons.map, 'Riesgo', () { Navigator.pop(ctx); _openPage(const RiskZonesScreen()); }),
          ],
        ),
      ),
    );
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
                  onDeleted: _dismissNews,
                ),
              ),
            ),
          IconButton(icon: const Icon(Icons.map), tooltip: 'Mapa', onPressed: _openMap),
          IconButton(icon: const Icon(Icons.settings), tooltip: 'Ajustes', onPressed: _openSettings),
        ],
      ),
      body: Column(
        children: [
          _buildPrepBar(theme),
          _buildFilterBar(theme),
          Expanded(
            child: FutureBuilder<List<Earthquake>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                final items = snapshot.data ?? const <Earthquake>[];
                if (items.isEmpty) {
                  return RefreshIndicator(
                    onRefresh: _refresh,
                    child: ListView(
                      children: const [
                        _EmptyState(),
                      ],
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: items.length + (items.isNotEmpty ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == 0 && items.isNotEmpty) {
                        final latest = items.first;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                              child: Text('Último sismo', style: theme.textTheme.titleSmall),
                            ),
                            _LatestCard(
                              event: latest,
                              onTap: () => _openDetail(latest),
                            ),
                            const SizedBox(height: 8),
                            if (items.length > 1)
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                child: Text('Recientes', style: theme.textTheme.titleSmall),
                              ),
                          ],
                        );
                      }
                      final adjusted = index - 1;
                      final e = items[adjusted];
                      return _EventTile(
                        event: e,
                        onTap: () => _openDetail(e),
                        theme: theme,
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

  Widget _buildPrepBar(ThemeData theme) {
    final quick = Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      height: 44,
      child: ElevatedButton.icon(
        onPressed: _openActions,
        icon: const Icon(Icons.radar, size: 18),
        label: const Text('Acciones rápidas'),
        style: ElevatedButton.styleFrom(
          backgroundColor: theme.colorScheme.primaryContainer,
          foregroundColor: theme.colorScheme.onPrimaryContainer,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );

    return quick;
  }

  Widget _buildFilterBar(ThemeData theme) {
    final chips = [
      _filterChip('M ≥ ${_minMag.toStringAsFixed(1)}', _minMag > 0, Icons.linear_scale, () {
        setState(() => _minMag = _minMag > 0 ? 0 : 3);
        _refresh();
      }),
      _filterChip(_dateRange == 0 ? 'Todo' : _dateRange == 1 ? '24h' : _dateRange == 2 ? '7d' : '30d', _dateRange > 0, Icons.schedule, () {
        setState(() => _dateRange = _dateRange > 0 ? 0 : 1);
        _refresh();
      }),
      _filterChip(_source, _source != 'Todas', Icons.public, () {
        setState(() => _source = _source == 'Todas' ? 'USGS' : 'Todas');
        _refresh();
      }),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: theme.colorScheme.surfaceContainerHighest,
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: chips.map((w) => Padding(padding: const EdgeInsets.only(right: 8), child: w)).toList()),
            ),
          ),
          IconButton(onPressed: _openSettings, icon: const Icon(Icons.tune, size: 18), tooltip: 'Filtros'),
        ],
      ),
    );
  }

  Widget _filterChip(String label, bool active, IconData icon, VoidCallback onTap) {
    final onSurface = active ? Theme.of(context).colorScheme.onPrimaryContainer : Theme.of(context).colorScheme.onSurfaceVariant;
    final container = active ? Theme.of(context).colorScheme.primaryContainer : Theme.of(context).colorScheme.surfaceContainerHighest;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: container,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.outlineVariant),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: onSurface),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(fontSize: 12, color: onSurface, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Widget _prepButton(IconData icon, String label, VoidCallback onTap) {
    return TextButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      style: TextButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: Colors.red.shade800,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
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

class _EventTile extends StatelessWidget {
  final Earthquake event;
  final VoidCallback onTap;
  final ThemeData theme;

  const _EventTile({
    required this.event,
    required this.onTap,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final mag = event.magnitude.toStringAsFixed(1);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: Earthquake.magnitudeColor(event.magnitude),
                radius: 18,
                child: Text('M$mag',
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(event.place, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodyMedium),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.access_time, size: 12, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(_formatTime(event.time), style: theme.textTheme.bodySmall),
                        const SizedBox(width: 10),
                        const Icon(Icons.waves, size: 12, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text('${event.depthKm.toStringAsFixed(1)} km', style: theme.textTheme.bodySmall),
                        const SizedBox(width: 10),
                        Text(event.source, style: theme.textTheme.bodySmall),
                      ],
                    ),
                  ],
                ),
              ),
              if (event.notified == 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.red.shade200)),
                  child: Text('NUEVO', style: TextStyle(fontSize: 10, color: Colors.red.shade700, fontWeight: FontWeight.w600)),
                ),
            ],
          ),
        ),
      ),
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

class _LatestCard extends StatelessWidget {
  final Earthquake event;
  final VoidCallback onTap;

  const _LatestCard({required this.event, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mag = event.magnitude.toStringAsFixed(1);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      color: theme.colorScheme.surfaceContainerHighest,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: Earthquake.magnitudeColor(event.magnitude),
                radius: 18,
                child: Text('M$mag',
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(event.place, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodyMedium),
                    const SizedBox(height: 2),
                    Text(
                      '${DateFormat('dd/MM HH:mm').format(event.time.toLocal())} · ${event.depthKm.toStringAsFixed(1)} km',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: theme.colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.explore_off_rounded, size: 56, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text('Sin eventos para este filtro', style: theme.textTheme.titleSmall, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text('Prueba ampliando el rango o ajusta la magnitud mínima.', style: theme.textTheme.bodyMedium, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(onPressed: () {}, icon: const Icon(Icons.tune), label: const Text('Ajustar filtros')),
          ],
        ),
      ),
    );
  }
}