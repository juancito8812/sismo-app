import 'package:flutter/material.dart';
import 'package:venezuela_sismos_app/data/local_db.dart';
import 'package:venezuela_sismos_app/data/earthquake.dart';
import 'package:venezuela_sismos_app/services/background_poller.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final Future<List<Earthquake>> _future;
  int _newCount = 0;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<void> _refresh() async {
    final latest = await _load();
    if (!mounted) return;
    setState(() {
      _future = Future.value(latest);
    });
  }

  Future<List<Earthquake>> _load() async {
    await _initBackground();
    final items = await LocalDb.instance.recent();
    final count = await LocalDb.instance.unnotifiedCount();
    if (mounted) {
      setState(() => _newCount = count);
    }
    return items;
  }

  Future<void> _initBackground() async {
    // Workmanager ya inicializado en main.dart
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sismos Venezuela'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          if (_newCount > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              child: Center(
                child: Chip(
                  label: Text('$_newCount nuevo(s)'),
                  onDeleted: () {
                    setState(() => _newCount = 0);
                  },
                ),
              ),
            ),
        ],
      ),
      body: FutureBuilder<List<Earthquake>>(
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
                    backgroundColor: _magnitudeColor(e.magnitude),
                    child: Text('M${e.magnitude.toStringAsFixed(1)}'),
                  ),
                  title: Text(e.place),
                  subtitle: Text(
                    '${_formatTime(e.time)} · ${e.depthKm.toStringAsFixed(1)} km',
                  ),
                  trailing: e.notified == 0
                      ? const Icon(Icons.fiber_new, color: Colors.red, size: 18)
                      : null,
                );
              },
            ),
          );
        },
      ),
    );
  }

  Color _magnitudeColor(double mag) {
    if (mag >= 6.0) return Colors.red;
    if (mag >= 5.0) return Colors.orange;
    if (mag >= 4.0) return Colors.amber;
    return Colors.green;
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inMinutes < 60) return '${diff.inMinutes} min';
    if (diff.inHours < 24) return '${diff.inHours} h';
    return '${diff.inDays} d';
  }
}
