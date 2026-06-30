import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:torch_light/torch_light.dart';

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
  final _player = AudioPlayer();
  bool _audioInitialized = false;

  // Patrón SOS: 3 cortos, 3 largos, 3 cortos
  static const _sosPatternMs = [
    200, 200, // S dot 1
    200, 200, // S dot 2
    200, 600, // S dot 3 + pause
    600, 200, // O dash 1
    600, 200, // O dash 2
    600, 600, // O dash 3 + pause
    200, 200, // S dot 1
    200, 200, // S dot 2
    200, 200, // S dot 3
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initAudio();
  }

  Future<void> _initAudio() async {
    try {
      await _player.setSourceUrl(
        'https://www.soundjay.com/misc/sounds/bell-ringing-05.mp3',
      );
      await _player.setVolume(1.0);
      _audioInitialized = true;
    } catch (_) {
      _audioInitialized = false;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sosTimer?.cancel();
    _player.dispose();
    _torchOff();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _stopSos();
    }
  }

  Future<void> _torchOn() async {
    try {
      await TorchLight.enableTorch();
    } catch (_) {
      // Flash no disponible en este dispositivo
    }
  }

  Future<void> _torchOff() async {
    try {
      await TorchLight.disableTorch();
    } catch (_) {}
  }

  Future<void> _playBeep() async {
    if (!_audioInitialized) return;
    try {
      await _player.stop();
      await _player.seek(Duration.zero);
      await _player.resume();
    } catch (_) {}
  }

  Future<void> _stopBeep() async {
    try {
      await _player.pause();
    } catch (_) {}
  }

  void _toggleSos() {
    if (_isSos) {
      _stopSos();
    } else {
      _startSos();
    }
  }

  Future<void> _startSos() async {
    setState(() => _isSos = true);
    await _torchOn();
    _sosStep = 0;
    _runSos();
  }

  void _runSos() {
    _sosTimer?.cancel();
    _sosTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (!mounted || !_isSos) {
        timer.cancel();
        return;
      }

      if (_sosStep < _sosPatternMs.length) {
        final isOn = _sosStep.isEven;
        final duration = _sosPatternMs[_sosStep];

        if (isOn) {
          _torchOn();
          _playBeep();
        } else {
          _torchOff();
          _stopBeep();
        }

        setState(() => _isTorch = isOn);
        _sosStep++;

        // Ajustar próxima ejecución basado en la duración
        timer.cancel();
        Future.delayed(Duration(milliseconds: duration), _runSos);
      } else {
        _sosStep = 0;
        _runSos();
      }
    });
  }

  Future<void> _stopSos() async {
    _sosTimer?.cancel();
    await _torchOff();
    await _stopBeep();
    if (mounted) setState(() { _isSos = false; _isTorch = false; });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
              const Text('Flash LED + pantalla blanca', style: TextStyle(fontSize: 16)),
              const Text('Sonido de alarma + vibración', style: TextStyle(fontSize: 16)),
              const Text('Parpadeo SOS automático', style: TextStyle(fontSize: 16)),
              const SizedBox(height: 32),
            ],
            if (_isTorch) ...[
              const Text('S O S', style: TextStyle(fontSize: 72, fontWeight: FontWeight.bold, letterSpacing: 16)),
              const SizedBox(height: 8),
              const Text('ENVIANDO SEÑAL', style: TextStyle(fontSize: 20, letterSpacing: 4)),
              const SizedBox(height: 32),
              const Icon(Icons.hearing, size: 48),
              const SizedBox(height: 8),
              const Text('Flash + Sonido activos', style: TextStyle(fontSize: 14)),
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
                    Text(_isSos ? 'DETENER SOS' : 'INICIAR SOS',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            if (!_isTorch)
              Text('El modo SOS parpadea el flash LED\ny emite sonido en código Morse: ··· −−− ···',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
