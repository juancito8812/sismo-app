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

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Earthquake>> _load() async {
    await _initBackground();
    return LocalDb.instance.recent();
  }

  Future<void> _initBackground() async {
    // Aquí se inicializa WorkManager con callbackDispatcher
    // En próximo paso: wiring completo
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sismos Venezuela'), backgroundColor: Theme.of(context).colorScheme.inversePrimary),
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
          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, index) {
              final e = items[index];
              return ListTile(
                leading: CircleAvatar(child: Text('M${e.magnitude.toStringAsFixed(1)}')),
                title: Text(e.place),
                subtitle: Text('${e.time.toLocal()} · ${e.depthKm.toStringAsFixed(1)} km'),
              );
            },
          );
        },
      ),
    );
  }
}
