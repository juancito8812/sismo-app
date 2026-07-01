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
        padding: const EdgeInsets.all(12),
        children: [
          _section(theme, Icons.priority_high, 'ANTES del sismo', Colors.orange, [
            '✅ Asegura muebles y estanterías a la pared',
            '✅ Prepara mochila 72h (agua, comida, linterna, botiquín)',
            '✅ Identifica zonas seguras: bajo mesas firmes, marcos de puerta',
            '✅ Define punto de encuentro familiar',
            '✅ Guarda documentos importantes en bolsa sellada',
            '✅ Ten a mano números de emergencia',
          ]),
          _section(theme, Icons.run_circle, 'DURANTE el sismo', Colors.red, [
            '🔴 AGÁCHATE sobre manos y rodillas',
            '🔴 CÚBRETE bajo una mesa resistente',
            '🔴 AGÁRRATE de la pata de la mesa hasta que pase',
            '✖ NO corras hacia afuera — peligro de caída de escombros',
            '✖ NO uses ascensores',
            '✖ Aléjate de ventanas, espejos y objetos que puedan caer',
          ]),
          _section(theme, Icons.healing, 'DESPUÉS del sismo', Colors.green, [
            '✅ Revisa si tú y tu familia están bien',
            '✅ Corta el suministro de gas si hay olor a fuga',
            '✅ Apaga la electricidad si hay daños visibles',
            '✅ Usa linterna, NO fósforos/velas (puede haber fuga de gas)',
            '✅ Prepárate para réplicas (pueden ocurrir minutos/horas después)',
            '✅ Revisa lesiones menores y aplica primeros auxilios',
            '📞 Solo llama si es emergencia real (no satures las líneas)',
          ]),
          _section(theme, Icons.checklist, 'Recomendaciones adicionales', Colors.blue, [
            '📱 Ten tu teléfono cargado y un power bank',
            '📻 Mantén una radio a pilas para recibir información oficial',
            '🚗 Revisa rutas de evacuación de tu zona',
            '🐾 Incluye a tus mascotas en el plan familiar',
            '🤝 Ayuda a vecinos de la tercera edad o con discapacidad',
          ]),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _section(ThemeData theme, IconData icon, String title, Color color, List<String> tips) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 8),
              Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
            ]),
            const Divider(),
            for (final tip in tips)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Text(tip, style: const TextStyle(fontSize: 14, height: 1.3)),
              ),
          ],
        ),
      ),
    );
  }
}
