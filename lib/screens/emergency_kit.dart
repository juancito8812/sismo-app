import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class EmergencyKitScreen extends StatefulWidget {
  const EmergencyKitScreen({super.key});

  @override
  State<EmergencyKitScreen> createState() => _EmergencyKitScreenState();
}

class _EmergencyKitScreenState extends State<EmergencyKitScreen> {
  final _items = <_KitItem>[
    _KitItem('Agua (1 galón por persona/día para 3 días)', 'water'),
    _KitItem('Comida no perecedera (enlatados, barras, granola)', 'food'),
    _KitItem('Abrelatas manual', 'opener'),
    _KitItem('Linterna con pilas extra', 'flashlight'),
    _KitItem('Radio a baterías o de manivela', 'radio'),
    _KitItem('Pilas de repuesto', 'batteries'),
    _KitItem('Botiquín de primeros auxilios', 'firstaid'),
    _KitItem('Silbato (para pedir ayuda)', 'whistle'),
    _KitItem('Mascarilla N95 / tapabocas', 'mask'),
    _KitItem('Cobija térmica / manta', 'blanket'),
    _KitItem('Cargador portátil / power bank', 'powerbank'),
    _KitItem('Documentos importantes en bolsa impermeable', 'docs'),
    _KitItem('Dinero en efectivo (billetes pequeños)', 'cash'),
    _KitItem('Multiherramienta / navaja', 'tool'),
    _KitItem('Cinta adhesiva gruesa', 'tape'),
    _KitItem('Bolsa de basura (10, usos múltiples)', 'bags'),
    _KitItem('Ropa de cambio y zapatos resistentes', 'clothes'),
    _KitItem('Medicamentos recetados (7 días)', 'meds'),
    _KitItem('Toallitas húmedas / gel antibacterial', 'hygiene'),
    _KitItem('Pito / silbato', 'whistle2'),
  ];

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  Future<void> _loadState() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      for (final item in _items) {
        item.checked = prefs.getBool('kit_${item.key}') ?? false;
      }
    });
  }

  Future<void> _toggle(_KitItem item) async {
    setState(() => item.checked = !item.checked);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('kit_${item.key}', item.checked);
  }

  Future<void> _resetAll() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reiniciar checklist'),
        content: const Text('¿Marcar todo como pendiente?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Reiniciar')),
        ],
      ),
    );
    if (confirm != true) return;
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      for (final item in _items) {
        item.checked = false;
        prefs.setBool('kit_${item.key}', false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final checkedCount = _items.where((i) => i.checked).length;
    final progress = checkedCount / _items.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kit de emergencia'),
        backgroundColor: theme.colorScheme.inversePrimary,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), tooltip: 'Reiniciar', onPressed: _resetAll),
        ],
      ),
      body: Column(
        children: [
          // Barra de progreso
          Container(
            padding: const EdgeInsets.all(12),
            color: theme.colorScheme.surfaceContainerHighest,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Progreso', style: theme.textTheme.bodyMedium),
                    Text('$checkedCount / ${_items.length}', style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 10,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation(
                      progress >= 1.0 ? Colors.green : theme.colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Lista
          Expanded(
            child: ListView.builder(
              itemCount: _items.length,
              itemBuilder: (context, index) {
                final item = _items[index];
                return CheckboxListTile(
                  title: Text(item.label, style: const TextStyle(fontSize: 14)),
                  value: item.checked,
                  onChanged: (_) => _toggle(item),
                  activeColor: Colors.green,
                  dense: true,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _KitItem {
  final String label;
  final String key;
  bool checked = false;
  _KitItem(this.label, this.key);
}
