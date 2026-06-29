import 'package:flutter/material.dart';
import 'package:venezuela_sismos_app/screens/home.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SismosApp());
}

class SismosApp extends StatelessWidget {
  const SismosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sismos Venezuela',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.red),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
