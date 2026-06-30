import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class EmergencyContactsScreen extends StatelessWidget {
  const EmergencyContactsScreen({super.key});

  static const _contacts = [
    _Contact('Protección Civil', '911', Icons.local_police, Colors.red),
    _Contact('Bomberos', '911', Icons.fire_truck, Colors.orange),
    _Contact('Cruz Roja', '0414-283.00.00', Icons.medical_services, Colors.redAccent),
    _Contact('CICPC (Emergencias)', '171', Icons.local_police, Colors.blueGrey),
    _Contact('IVSS (Ambulancias)', '0800-487.77.55', Icons.airport_shuttle, Colors.teal),
    _Contact('Ministerio Salud', '0800-SALUD', Icons.local_hospital, Colors.blue),
    _Contact('INFRASTRUCTURA (Vialidad)', '0800-746.87.47', Icons.signpost, Colors.brown),
    _Contact('SENIAT (Aduanas)', '0800-736.42.81', Icons.account_balance, Colors.indigo),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Contactos de emergencia'),
        backgroundColor: theme.colorScheme.inversePrimary,
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Card(
            color: Colors.red.shade50,
            child: const Padding(
              padding: EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.red, size: 20),
                  SizedBox(width: 8),
                  Expanded(child: Text('Toca un número para llamar directamente', style: TextStyle(fontSize: 13))),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          for (final c in _contacts)
            Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: c.color.withOpacity(0.2),
                  child: Icon(c.icon, color: c.color),
                ),
                title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(c.number),
                trailing: const Icon(Icons.phone, color: Colors.green),
                onTap: () => _call(context, c.number),
              ),
            ),
          const SizedBox(height: 16),
          Text('Números de Venezuela',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Future<void> _call(BuildContext ctx, String number) async {
    final clean = number.replaceAll(RegExp(r'[^\d+]'), '');
    final uri = Uri.parse('tel:$clean');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(content: Text('No se puede llamar a $clean')),
      );
    }
  }
}

class _Contact {
  final String name;
  final String number;
  final IconData icon;
  final Color color;
  const _Contact(this.name, this.number, this.icon, this.color);
}
