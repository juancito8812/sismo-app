import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class FamilyPlanScreen extends StatefulWidget {
  const FamilyPlanScreen({super.key});

  @override
  State<FamilyPlanScreen> createState() => _FamilyPlanScreenState();
}

class _FamilyPlanScreenState extends State<FamilyPlanScreen> {
  final _meetingCtrl = TextEditingController();
  final _contactCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String _savedMeeting = '';
  String _savedContacts = '';
  String _savedNotes = '';
  bool _showMap = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _savedMeeting = prefs.getString('plan_meeting') ?? '';
      _savedContacts = prefs.getString('plan_contacts') ?? '';
      _savedNotes = prefs.getString('plan_notes') ?? '';
      _meetingCtrl.text = _savedMeeting;
      _contactCtrl.text = _savedContacts;
      _notesCtrl.text = _savedNotes;
    });
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('plan_meeting', _meetingCtrl.text);
    await prefs.setString('plan_contacts', _contactCtrl.text);
    await prefs.setString('plan_notes', _notesCtrl.text);
    setState(() {
      _savedMeeting = _meetingCtrl.text;
      _savedContacts = _contactCtrl.text;
      _savedNotes = _notesCtrl.text;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Plan guardado')),
      );
    }
  }

  @override
  void dispose() {
    _meetingCtrl.dispose();
    _contactCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Plan familiar'),
        backgroundColor: theme.colorScheme.inversePrimary,
        actions: [
          IconButton(icon: const Icon(Icons.save), onPressed: _save),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Punto de encuentro
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(Icons.location_on, color: Colors.green.shade700),
                    const SizedBox(width: 8),
                    Text('Punto de encuentro', style: theme.textTheme.titleSmall),
                  ]),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _meetingCtrl,
                    decoration: const InputDecoration(
                      hintText: 'Ej: Parque Miranda, entrada principal',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () => setState(() => _showMap = !_showMap),
                    icon: const Icon(Icons.map, size: 18),
                    label: const Text('Ver en mapa'),
                  ),
                  if (_showMap)
                    SizedBox(
                      height: 200,
                      child: FlutterMap(
                        options: const MapOptions(center: LatLng(8.0, -66.0), zoom: 5),
                        children: [
                          TileLayer(
                            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.juancito8812.sismo_ve',
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Contactos familiares
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(Icons.people, color: Colors.blue.shade700),
                    const SizedBox(width: 8),
                    Text('Contactos familiares', style: theme.textTheme.titleSmall),
                  ]),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _contactCtrl,
                    decoration: const InputDecoration(
                      hintText: 'Mamá: 0412-xxx\nPapá: 0416-xxx\nTío: ...',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 4,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Notas
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(Icons.notes, color: Colors.orange.shade700),
                    const SizedBox(width: 8),
                    Text('Notas importantes', style: theme.textTheme.titleSmall),
                  ]),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _notesCtrl,
                    decoration: const InputDecoration(
                      hintText: 'Cortar gas en: ...\nRutas de evacuación: ...\nAlergias/medicamentos: ...',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 4,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Botón "Estoy bien" — real via SMS/WhatsApp
          Card(
            color: Colors.green.shade50,
            child: ListTile(
              leading: const Icon(Icons.check_circle, color: Colors.green, size: 36),
              title: const Text('Estoy bien', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Notifica a tus contactos'),
              trailing: PopupMenuButton<String>(
                icon: const Icon(Icons.send, color: Colors.green),
                onSelected: (method) {
                  final msg = '¡Estoy bien! 🙏 SismoVE - Sismo detectado. ¿Todos bien?';
                  final contactList = _contactCtrl.text;
                  for (final line in contactList.split('\n')) {
                    final parts = line.split(':');
                    if (parts.length >= 2) {
                      final num = parts.sublist(1).join(':').trim();
                      if (method == 'sms') _sendMsg('sms', num, msg);
                      else _sendMsg('wa', num, msg);
                    }
                  }
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Enviado por ${method == 'sms' ? 'SMS' : 'WhatsApp'}')),
                  );
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'sms', child: ListTile(leading: Icon(Icons.sms), title: Text('SMS'), dense: true)),
                  const PopupMenuItem(value: 'wa', child: ListTile(leading: Icon(Icons.chat), title: Text('WhatsApp'), dense: true)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Future<void> _sendMsg(String type, String number, String text) async {
    final clean = number.replaceAll(RegExp(r'[^\d+]'), '');
    if (clean.isEmpty) return;
    final uri = type == 'sms'
        ? Uri.parse('sms:$clean?body=${Uri.encodeComponent(text)}')
        : Uri.parse('https://wa.me/$clean?text=${Uri.encodeComponent(text)}');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }
}
