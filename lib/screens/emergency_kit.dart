import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class EmergencyKitScreen extends StatefulWidget {
  const EmergencyKitScreen({super.key});

  @override
  State<EmergencyKitScreen> createState() => _EmergencyKitScreenState();
}

class _EmergencyKitScreenState extends State<EmergencyKitScreen> {
  final _categories = [
    _KitCategory('Agua y Comida', Icons.restaurant, Colors.blue, [
      _KitItem('Agua (1 galón por persona/día)', 'water'),
      _KitItem('Comida no perecedera (enlatados, barras)', 'food'),
      _KitItem('Abrelatas manual', 'opener'),
      _KitItem('Platos y cubiertos desechables', 'dishes'),
    ]),
    _KitCategory('Seguridad y Herramientas', Icons.build, Colors.orange, [
      _KitItem('Linterna con pilas extra', 'flashlight'),
      _KitItem('Radio a baterías o de manivela', 'radio'),
      _KitItem('Pilas de repuesto', 'batteries'),
      _KitItem('Silbato', 'whistle'),
      _KitItem('Multiherramienta / navaja', 'tool'),
      _KitItem('Encendedor / fósforos en bolsa sellada', 'matches'),
    ]),
    _KitCategory('Primeros Auxilios', Icons.medical_services, Colors.red, [
      _KitItem('Botiquín de primeros auxilios', 'firstaid'),
      _KitItem('Medicamentos recetados (7 días)', 'meds'),
      _KitItem('Vendas, gasas, esparadrapo', 'bandages'),
      _KitItem('Alcohol / antiséptico', 'antiseptic'),
      _KitItem('Guantes de látex', 'gloves'),
    ]),
    _KitCategory('Higiene y Confort', Icons.clean_hands, Colors.teal, [
      _KitItem('Toallitas húmedas / gel antibacterial', 'wipes'),
      _KitItem('Bolsa de basura (10+), precinto', 'bags'),
      _KitItem('Papel higiénico', 'tp'),
      _KitItem('Ropa de abrigo y frazada', 'blanket'),
      _KitItem('Cepillo de dientes / pasta', 'hygiene'),
    ]),
    _KitCategory('Documentos y Comunicación', Icons.description, Colors.indigo, [
      _KitItem('Cédula / pasaporte (copia)', 'id'),
      _KitItem('Dinero en efectivo', 'cash'),
      _KitItem('Cargador portátil / power bank', 'charger'),
      _KitItem('Lista de contactos de emergencia', 'contacts'),
      _KitItem('Mapa de la zona / rutas de evacuación', 'map'),
    ]),
  ];

  final _checked = <String>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _checked.addAll(prefs.getStringList('kit_checked') ?? []));
  }

  Future<void> _toggle(String key) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      if (_checked.contains(key)) { _checked.remove(key); } else { _checked.add(key); }
    });
    await prefs.setStringList('kit_checked', _checked.toList());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = _categories.fold(0, (s, c) => s + c.items.length);
    final done = _checked.length;
    final progress = total > 0 ? done / total : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kit de emergencia'),
        backgroundColor: theme.colorScheme.inversePrimary,
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          // Barra de progreso
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(Icons.inventory_2, size: 18, color: Colors.blue),
                  const SizedBox(width: 6),
                  Text('Progreso: $done/$total ítems', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                ]),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(value: progress, minHeight: 10,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation(progress == 1.0 ? Colors.green : Colors.blue)),
                ),
              ],
            ),
          ),
          // Categorías
          for (final cat in _categories) ...[
            Card(
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Icon(cat.icon, size: 18, color: cat.color),
                      const SizedBox(width: 6),
                      Text(cat.name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: cat.color)),
                      const Spacer(),
                      Text('${_checked.where((k) => cat.items.any((i) => i.key == k)).length}/${cat.items.length}',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                    ]),
                    const Divider(height: 8),
                    ...cat.items.map((item) => CheckboxListTile(
                      value: _checked.contains(item.key),
                      onChanged: (_) => _toggle(item.key),
                      title: Text(item.label, style: const TextStyle(fontSize: 13)),
                      dense: true,
                      controlAffinity: ListTileControlAffinity.leading,
                      visualDensity: VisualDensity.compact,
                    )),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _KitCategory {
  final String name;
  final IconData icon;
  final Color color;
  final List<_KitItem> items;
  const _KitCategory(this.name, this.icon, this.color, this.items);
}

class _KitItem {
  final String label;
  final String key;
  const _KitItem(this.label, this.key);
}
