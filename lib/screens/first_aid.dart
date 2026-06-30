import 'package:flutter/material.dart';

class FirstAidScreen extends StatelessWidget {
  const FirstAidScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Primeros auxilios'),
        backgroundColor: theme.colorScheme.inversePrimary,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _section(theme, Icons.favorite, 'RCP (Reanimación)', Colors.red, [
            '1. Verifica que la persona no responda ni respire',
            '2. Llama a emergencias (911)',
            '3. Coloca a la persona boca arriba en superficie firme',
            '4. Arrodíllate a la altura de sus hombros',
            '5. Coloca el talón de una mano en el centro del pecho',
            '6. La otra mano sobre la primera, dedos entrelazados',
            '7. Presiona fuerte y rápido (100-120 compresiones/min)',
            '8. Comprime al menos 5 cm de profundidad',
            '9. Continúa hasta que llegue ayuda o la persona reaccione',
          ]),
          const SizedBox(height: 12),
          _section(theme, Icons.water_drop, 'Hemorragias', Colors.red.shade700, [
            '1. Aplica presión directa sobre la herida con una gasa o paño limpio',
            '2. Mantén la presión constante durante al menos 10 minutos',
            '3. Eleva la zona afectada por encima del corazón si es posible',
            '4. NO retires el vendaje si se empapa — agrega otro encima',
            '5. Si la hemorragia no cede, busca ayuda médica urgente',
            '6. Para hemorragias nasales: inclina la cabeza hacia adelante',
          ]),
          const SizedBox(height: 12),
          _section(theme, Icons.accessible, 'Fracturas y esguinces', Colors.orange.shade700, [
            '1. NO muevas a la persona si sospechas fractura de columna',
            '2. Inmoviliza la zona lesionada con una férula improvisada',
            '3. Usa tablas, revistas, cartón como férula',
            '4. Aplica hielo envuelto en un paño para reducir inflamación',
            '5. NO intentes reubicar el hueso',
            '6. Traslada a un centro de salud lo antes posible',
          ]),
          const SizedBox(height: 12),
          _section(theme, Icons.local_fire_department, 'Quemaduras', Colors.deepOrange, [
            '1. Enfría la quemadura con agua fría (no hielo) por 10-20 min',
            '2. NO apliques mantequilla, pasta dental ni cremas',
            '3. Cubre con gasa estéril o paño limpio y húmedo',
            '4. NO revientes las ampollas',
            '5. Si es grave (tercer grado), busca ayuda médica urgente',
          ]),
          const SizedBox(height: 12),
          _section(theme, Icons.psychology, 'Shock (estado de choque)', Colors.purple, [
            '1. Acuesta a la persona boca arriba',
            '2. Eleva sus piernas unos 30 cm si no hay fracturas',
            '3. Cúbrela con una manta o chaqueta',
            '4. Mantén la calma y háblale con voz tranquila',
            '5. NO le des agua ni comida si está inconsciente',
            '6. Busca ayuda médica inmediatamente',
          ]),
          const SizedBox(height: 12),
          _section(theme, Icons.air, 'Atragantamiento (Maniobra de Heimlich)', Colors.blue.shade700, [
            '1. Colócate detrás de la persona',
            '2. Rodea su cintura con tus brazos',
            '3. Cierra un puño y colócalo sobre el ombligo',
            '4. Agarra el puño con la otra mano',
            '5. Presiona hacia adentro y arriba con movimientos rápidos',
            '6. Repite hasta que expulse el objeto o pierda el conocimiento',
          ]),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _section(ThemeData theme, IconData icon, String title, Color color, List<String> steps) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(width: 8),
              Expanded(child: Text(title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold))),
            ]),
            const Divider(),
            for (final step in steps)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• ', style: TextStyle(fontSize: 14)),
                    Expanded(child: Text(step, style: const TextStyle(fontSize: 14))),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
