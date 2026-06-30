import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class TorchSosScreen extends StatefulWidget {
  const TorchSosScreen({super.key});

  @override
  State<TorchSosScreen> createState() => _TorchSosScreenState();
}

class _TorchSosScreenState extends State<TorchSosScreen> with WidgetsBindingObserver {
  bool _isSos = false;
  bool _isTorch = false;
  Timer? _sosTimer;
  int _sosStep = 0;
  static const _sosPattern = [
    // S: 3 cortos
    Duration(milliseconds: 200), Duration(milliseconds: 200),
    Duration(milliseconds: 200), Duration(milliseconds: 200),
    Duration(milliseconds: 200), Duration(milliseconds: 200),
    // O: 3 largos
    Duration(milliseconds: 200), Duration(milliseconds: 600),
    Duration(milliseconds: 600), Duration(milliseconds: 200),
    Duration(milliseconds: 600), Duration(milliseconds: 200),
    // S: 3 cortos
    Duration(milliseconds: 200), Duration(milliseconds: 200),
    Duration(milliseconds: 200), Duration(milliseconds: 200),
    Duration(milliseconds: 200), Duration(milliseconds: 600),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sosTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _stopSos();
    }
  }

  void _toggleSos() {
    setState(() => _isSos = !_isSos);
    if (_isSos) {
      _isTorch = true;
      _runSosPattern();
    } else {
      _sosTimer?.cancel();
      if (mounted) setState(() => _isTorch = false);
    }
  }

  void _runSosPattern() {
    _sosStep = 0;
    _sosTimer = Timer.periodic(const Duration(milliseconds: 300), (timer) {
      if (!mounted || !_isSos) {
        timer.cancel();
        return;
      }
      if (_sosStep < _sosPattern.length) {
        final duration = _sosPattern[_sosStep];
        setState(() => _isTorch = _sosStep.isEven);
        _sosStep++;
      } else {
        _sosStep = 0;
      }
    });
  }

  void _stopSos() {
    _sosTimer?.cancel();
    if (mounted) setState(() { _isSos = false; _isTorch = false; });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Brillo máximo en modo SOS
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: _isTorch ? Brightness.dark : Brightness.light,
    ));

    return Scaffold(
      backgroundColor: _isTorch ? Colors.white : theme.colorScheme.surface,
      appBar: _isTorch
          ? null
          : AppBar(
              title: const Text('Linterna + SOS'),
              backgroundColor: theme.colorScheme.inversePrimary,
            ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (!_isTorch) ...[
              const Icon(Icons.flashlight_on, size: 80, color: Colors.amber),
              const SizedBox(height: 16),
              const Text('Pantalla blanca a máximo brillo', style: TextStyle(fontSize: 16)),
              const Text('Parpadeo SOS automático', style: TextStyle(fontSize: 16)),
              const SizedBox(height: 32),
            ],
            if (_isTorch) ...[
              const Text('S O S', style: TextStyle(fontSize: 72, fontWeight: FontWeight.bold, letterSpacing: 16)),
              const SizedBox(height: 8),
              const Text('ENVIANDO SEÑAL', style: TextStyle(fontSize: 20, letterSpacing: 4)),
              const SizedBox(height: 32),
              const Icon(Icons.hearing, size: 48),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: 200,
              height: 64,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isSos ? Colors.red : Colors.amber,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
                ),
                onPressed: _toggleSos,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(_isSos ? Icons.stop : Icons.flash_on),
                    const SizedBox(width: 8),
                    Text(_isSos ? 'DETENER SOS' : 'INICIAR SOS', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            if (!_isTorch)
              Text('El modo SOS parpadea:\n··· −−− ··· (SOS en código Morse)',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
