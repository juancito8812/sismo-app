import 'package:flutter/material.dart';

class SafetyGuideScreen extends StatelessWidget {
  const SafetyGuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Guía de seguridad'),
        backgroundColor: theme.colorScheme.inversePrimary,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sectionHeader(theme, Icons.warning_amber, 'ANTES del sismo', Colors.orange),
          _tip('Asegura muebles, estanterías y electrodomésticos a la pared'),
          _tip('Prepara una mochila de emergencia (72h) con agua, comida, linterna, botiquín'),
          _tip('Identifica zonas seguras en tu hogar: bajo mesas firmes, marcos de puertas'),
          _tip('Acuerda un punto de encuentro familiar'),
          _tip('Guarda números de emergencia en tu teléfono'),
          _tip('Ten a mano linterna, pilas, radio a baterías'),
          const SizedBox(height: 16),
          _sectionHeader(theme, Icons.run_circle, 'DURANTE el sismo', Colors.red),
          _tip('**AGÁCHATE** sobre manos y rodillas'),
          _tip('**CÚBRETE** la cabeza y cuello bajo una mesa firme'),
          _tip('**AGRÁRRATE** fuerte hasta que deje de temblar'),
          _tip('Aléjate de ventanas, espejos y objetos que puedan caer'),
          _tip('NO uses ascensores'),
          _tip('Si estás en la calle, aléjate de edificios, postes y cables'),
          _tip('Si manejas, estaciónate en lugar seguro, lejos de puentes/túneles'),
          const SizedBox(height: 16),
          _sectionHeader(theme, Icons.healing, 'DESPUÉS del sismo', Colors.blue),
          _tip('Revisa si hay heridos y aplica primeros auxilios básicos'),
          _tip('Corta el suministro de gas y electricidad si hay fugas'),
          _tip('Prepárate para réplicas (pueden ocurrir minutos/días después)'),
          _tip('Usa linterna, no fósforos ni velas (puede haber fugas de gas)'),
          _tip('Mantente informado por radio o fuentes oficiales'),
          _tip('No uses el teléfono salvo emergencias extremas'),
          _tip('Si estás en la costa, aléjate de la playa (riesgo de tsunami)'),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _sectionHeader(ThemeData theme, IconData icon, String title, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 8),
          Text(title, style: theme.textTheme.titleMedium?.copyWith(color: color, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _tip(String text) {
    final isBold = text.contains('**');
    final clean = text.replaceAll('**', '');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(fontSize: 16)),
          Expanded(
            child: Text(
              clean,
              style: TextStyle(fontSize: 15, fontWeight: isBold ? FontWeight.bold : FontWeight.normal),
            ),
          ),
        ],
      ),
    );
  }
}
