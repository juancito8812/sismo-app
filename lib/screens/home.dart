import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/local_db.dart';
import '../data/earthquake.dart';
import '../services/alert_engine.dart';
import '../services/push_notification_service.dart';
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
    PushNotificationService.onTapNotification = _onTapPushNotification;
    _future = _load();
  }

  static const _lastSeenKey = 'last_seen_events';

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
    // Badge "nuevo(s)": eventos llegados desde la última visita.
    final lastSeen = await _lastSeenMs();
    final count = await LocalDb.instance.countSince(sinceEpochMs: lastSeen);
    if (mounted) setState(() => _newCount = count);
    return items;
  }

  Future<int> _lastSeenMs() async {
    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey(_lastSeenKey)) {
      final now = DateTime.now().millisecondsSinceEpoch;
      await prefs.setInt(_lastSeenKey, now);
      return now;
    }
    return prefs.getInt(_lastSeenKey) ?? 0;
  }

  Future<void> _refresh() async {
    // Pull-to-refresh también trae eventos nuevos de inmediato.
    await AlertEngine.instance.syncEvents();
    final latest = await _load();
    if (!mounted) return;
    setState(() => _future = Future.value(latest));
  }

  /// Abre el detalle del sismo notificado por push; si el evento ya no está
  /// en la DB (fue podado), simplemente recarga la lista.
  Future<void> _onTapPushNotification() async {
    // Firebase puede no haberse inicializado aún (notificación obtenida
    // durante el arranque, antes de initialize()); forzamos el init.
    await PushNotificationService.instance.initialize();
    if (!mounted) return;
    final payload = PushNotificationService.instance.initialNotificationPayload;
    PushNotificationService.instance.clearInitialNotificationPayload();
    if (payload == null) return;
    final eq = await LocalDb.instance.byId(payload.id);
    if (!mounted) return;
    if (eq != null) {
      _openDetail(eq);
    } else {
      setState(() => _future = _load());
    }
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

  Future<void> _dismissNews() async {
    setState(() => _newCount = 0);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastSeenKey, DateTime.now().millisecondsSinceEpoch);
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
                child: Semantics(
                  label: '$_newCount sismo(s) nuevo(s), toca para descartar',
                  child: Chip(
                    visualDensity: VisualDensity.compact,
                    label: Text('$_newCount nuevo(s)'),
                    onDeleted: _dismissNews,
                  ),
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
                if (items.isEmpty) return const Center(child: Text('Sin eventos registrados'));
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
                          child: Text('M${e.magnitude.toStringAsFixed(1)}',
                              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                        title: Text(e.place, maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text('${_formatTime(e.time)} · ${e.depthKm.toStringAsFixed(1)} km · ${e.source}'),
                        trailing: e.notified == 0 ? const Icon(Icons.fiber_new, color: Colors.red, size: 18) : null,
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

  Widget _buildPrepBar(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      color: Colors.red.shade50,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // — Monitoreo —
          Row(children: [
            Icon(Icons.satellite_alt, size: 14, color: Colors.red.shade800),
            const SizedBox(width: 4),
            Text('MONITOREO', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.red.shade800, letterSpacing: 1)),
          ]),
          const SizedBox(height: 4),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _prepButton(Icons.map, 'Mapa', () => _openPage(const MapScreen())),
                const SizedBox(width: 6),
                _prepButton(Icons.settings, 'Ajustes', () => _openSettings()),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // — Preparación —
          Row(children: [
            Icon(Icons.medical_services, size: 14, color: Colors.red.shade800),
            const SizedBox(width: 4),
            Text('PREPARACIÓN', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.red.shade800, letterSpacing: 1)),
          ]),
          const SizedBox(height: 4),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _prepButton(Icons.healing, 'Guía', () => _openPage(const SafetyGuideScreen())),
                const SizedBox(width: 6),
                _prepButton(Icons.emergency, 'Kit', () => _openPage(const EmergencyKitScreen())),
                const SizedBox(width: 6),
                _prepButton(Icons.phone, 'Contactos', () => _openPage(const EmergencyContactsScreen())),
                const SizedBox(width: 6),
                _prepButton(Icons.flash_on, 'SOS', () => _openPage(const TorchSosScreen())),
                const SizedBox(width: 6),
                _prepButton(Icons.people, 'Familia', () => _openPage(const FamilyPlanScreen())),
                const SizedBox(width: 6),
                _prepButton(Icons.report, 'Reportar', () => _openPage(const FeltReportScreen())),
                const SizedBox(width: 6),
                _prepButton(Icons.medical_services, 'Auxilios', () => _openPage(const FirstAidScreen())),
                const SizedBox(width: 6),
                _prepButton(Icons.map, 'Riesgo', () => _openPage(const RiskZonesScreen())),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _prepButton(IconData icon, String label, VoidCallback onTap) {
    return TextButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 20),
      label: Text(label, style: const TextStyle(fontSize: 13)),
      style: TextButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: Colors.red.shade800,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        minimumSize: const Size(64, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }

  Widget _buildFilterBar(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      color: theme.colorScheme.surfaceContainerHighest,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _filterChip('M ≥ ${_minMag.toStringAsFixed(0)}', _minMag > 0, () {
              setState(() => _minMag = _minMag > 0 ? 0 : 3);
              _refresh();
            }),
            const SizedBox(width: 8),
            _filterChip(['Todo', 'Últ. 24h', 'Últ. 7d', 'Últ. 30d'][_dateRange], _dateRange > 0, () {
              setState(() => _dateRange = _dateRange > 0 ? 0 : 1);
              _refresh();
            }),
            const SizedBox(width: 8),
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
      label: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
      selected: active,
      onSelected: (_) => onTap(),
      visualDensity: VisualDensity.comfortable,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
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
