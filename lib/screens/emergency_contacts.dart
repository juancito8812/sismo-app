import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class EmergencyContactsScreen extends StatefulWidget {
  const EmergencyContactsScreen({super.key});

  @override
  State<EmergencyContactsScreen> createState() => _EmergencyContactsScreenState();
}

class _EmergencyContactsScreenState extends State<EmergencyContactsScreen> {
  List<_Contact> _customContacts = [];
  bool _loading = false;

  static const _presetContacts = [
    _Contact('Protección Civil', '911', Icons.local_police, Colors.red, true),
    _Contact('Bomberos', '911', Icons.fire_truck, Colors.orange, true),
    _Contact('Cruz Roja', '0414-283.00.00', Icons.medical_services, Colors.redAccent, true),
    _Contact('CICPC (Emergencias)', '171', Icons.local_police, Colors.blueGrey, true),
    _Contact('IVSS (Ambulancias)', '0800-487.77.55', Icons.airport_shuttle, Colors.teal, true),
    _Contact('Ministerio Salud', '0800-SALUD', Icons.local_hospital, Colors.blue, true),
  ];

  static const _quickMessages = [
    'Estoy bien 🙏',
    'Necesito ayuda 🆘',
    '¿Estás bien? ¿Dónde estás?',
    'Voy al punto de encuentro',
    'Llámame cuando puedas',
  ];

  @override
  void initState() {
    super.initState();
    _loadCustom();
  }

  Future<void> _loadCustom() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('emergency_contacts') ?? [];
    setState(() {
      _customContacts = saved.map((e) {
        final parts = e.split('|');
        return _Contact(parts[0], parts.length > 1 ? parts[1] : '', Icons.person, Colors.blueGrey, false);
      }).toList();
    });
  }

  Future<void> _saveCustom() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('emergency_contacts',
      _customContacts.map((c) => '${c.name}|${c.number}').toList());
  }

  Future<void> _pickContact() async {
    if (!await FlutterContacts.requestPermission()) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Permiso denegado para acceder a contactos')));
      return;
    }
    setState(() => _loading = true);
    try {
      final contact = await FlutterContacts.openExternalPick();
      if (contact != null) {
        final phone = contact.phones.isNotEmpty ? contact.phones.first.number : 'Sin teléfono';
        setState(() {
          _customContacts.add(_Contact(contact.displayName, phone, Icons.person, Colors.blueGrey, false));
        });
        _saveCustom();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _removeContact(int index) async {
    setState(() => _customContacts.removeAt(index));
    _saveCustom();
  }

  Future<void> _sendSms(String number, String message) async {
    final clean = number.replaceAll(RegExp(r'[^\d+]'), '');
    final uri = Uri.parse('sms:$clean?body=${Uri.encodeComponent(message)}');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _sendWhatsApp(String number, String message) async {
    final clean = number.replaceAll(RegExp(r'[^\d+]'), '');
    final uri = Uri.parse('https://wa.me/$clean?text=${Uri.encodeComponent(message)}');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _call(String number) async {
    final clean = number.replaceAll(RegExp(r'[^\d+]'), '');
    final uri = Uri.parse('tel:$clean');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  void _showMessageSheet(BuildContext ctx, String name, String number) {
    showModalBottomSheet(
      context: ctx,
      builder: (sheetCtx) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Enviar mensaje a $name', style: Theme.of(ctx).textTheme.titleMedium),
            const SizedBox(height: 12),
            for (final msg in _quickMessages)
              ListTile(
                title: Text(msg),
                leading: const Icon(Icons.message, size: 20),
                dense: true,
                onTap: () {
                  Navigator.pop(sheetCtx);
                  _showSendPicker(ctx, number, msg);
                },
              ),
          ],
        ),
      ),
    );
  }

  void _showSendPicker(BuildContext ctx, String number, String message) {
    showModalBottomSheet(
      context: ctx,
      builder: (sheetCtx) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Enviar por...', style: Theme.of(ctx).textTheme.titleMedium),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.sms, color: Colors.green),
              title: const Text('SMS'),
              onTap: () { Navigator.pop(sheetCtx); _sendSms(number, message); },
            ),
            ListTile(
              leading: const Icon(Icons.chat, color: Colors.teal),
              title: const Text('WhatsApp'),
              onTap: () { Navigator.pop(sheetCtx); _sendWhatsApp(number, message); },
            ),
          ],
        ),
      ),
    );
  }

  Widget _contactTile(_Contact c, {VoidCallback? onRemove}) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(backgroundColor: c.color.withOpacity(0.2), child: Icon(c.icon, color: c.color, size: 20)),
        title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Text(c.number, style: const TextStyle(fontSize: 12)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.message, size: 18, color: Colors.teal),
              tooltip: 'Mensaje rápido',
              onPressed: () => _showMessageSheet(context, c.name, c.number),
            ),
            IconButton(
              icon: const Icon(Icons.phone, size: 18, color: Colors.green),
              tooltip: 'Llamar',
              onPressed: () => _call(c.number),
            ),
            if (onRemove != null)
              IconButton(
                icon: const Icon(Icons.close, size: 16, color: Colors.grey),
                onPressed: onRemove,
              ),
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
        title: const Text('Contactos de emergencia'),
        backgroundColor: theme.colorScheme.inversePrimary,
        actions: [
          TextButton.icon(
            onPressed: _loading ? null : _pickContact,
            icon: _loading
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.person_add),
            label: const Text('Agregar'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          // Mensajes rápidos — acceso directo
          Card(
            color: Colors.blue.shade50,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Icon(Icons.quickreply, size: 18, color: Colors.blue),
                    const SizedBox(width: 6),
                    Text('Mensajes rápidos', style: theme.textTheme.titleSmall),
                  ]),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6, runSpacing: 4,
                    children: _quickMessages.map((msg) => ActionChip(
                      label: Text(msg, style: const TextStyle(fontSize: 11)),
                      onPressed: () => _showSendPicker(context, '', msg),
                      visualDensity: VisualDensity.compact,
                    )).toList(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Contactos preseleccionados (Venezuela)
          ..._presetContacts.map((c) => _contactTile(c)),

          // Contactos personalizados
          if (_customContacts.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.only(top: 8, bottom: 4),
              child: Text('Mis contactos', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            ),
            for (var i = 0; i < _customContacts.length; i++)
              _contactTile(_customContacts[i], onRemove: () => _removeContact(i)),
          ],

          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _Contact {
  final String name;
  final String number;
  final IconData icon;
  final Color color;
  final bool preset;
  const _Contact(this.name, this.number, this.icon, this.color, [this.preset = false]);
}
