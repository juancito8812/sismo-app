import 'dart:async';
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
  bool _audioOk = false;
  bool _torchOk = false;
  bool _torchChecked = false;
  String? _feedback;

  static const _sosPatternMs = [
    200, 200, 200, 200, 200, 600,
    600, 200, 600, 200, 600, 600,
    200, 200, 200, 200, 200, 200,
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkTorch();
    _initAudio();
  }

  Future<void> _checkTorch() async {
    try {
      await TorchLight.enableTorch();
      await TorchLight.disableTorch();
      if (mounted) setState(() { _torchOk = true; _torchChecked = true; });
    } catch (_) {
      if (mounted) setState(() { _torchOk = false; _torchChecked = true; });
    }
  }

  Future<void> _initAudio() async {
    try {
      await _player.setSource(AssetSource('sounds/sos_beep.wav'));
      await _player.setVolume(1.0);
      _audioOk = true;
    } catch (_) {
      _audioOk = false;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sosTimer?.cancel();
    _player.dispose();
    _torchSet(false);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) _stopSos();
  }

  Future<void> _torchSet(bool on) async {
    if (!_torchOk) return;
    try {
      if (on) await TorchLight.enableTorch();
      else await TorchLight.disableTorch();
    } catch (_) {}
  }

  Future<void> _playBeep() async {
    if (!_audioOk) return;
    try { await _player.stop(); await _player.seek(Duration.zero); await _player.resume(); }
    catch (_) {}
  }

  Future<void> _stopBeep() async {
    try { await _player.pause(); } catch (_) {}
  }

  void _vibrate() {
    HapticFeedback.heavyImpact();
  }

  void _toggleSos() {
    if (_isSos) _stopSos();
    else _startSos();
  }

  void _startSos() {
    setState(() {
      _isSos = true;
      _feedback = 'SOS activado';
    });
    _torchSet(true);
    _sosStep = 0;
    _runSos();
  }

  void _runSos() {
    _sosTimer?.cancel();
    _sosTimer = Timer.periodic(const Duration(milliseconds: 30), (timer) {
      if (!mounted || !_isSos) { timer.cancel(); return; }

      if (_sosStep < _sosPatternMs.length) {
        final isOn = _sosStep.isEven;
        final duration = _sosPatternMs[_sosStep];

        if (isOn) {
          _torchSet(true);
          _playBeep();
          _vibrate();
        } else {
          _torchSet(false);
          _stopBeep();
        }

        setState(() => _isTorch = isOn);
        _sosStep++;
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
    await _torchSet(false);
    await _stopBeep();
    if (mounted) {
      setState(() {
        _isSos = false;
        _isTorch = false;
        _feedback = 'SOS detenido';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: _isTorch ? Brightness.dark : Brightness.light,
    ));

    return PopScope(
      canPop: !_isSos,
      onPopInvokedWithResult: (didPop, _) async {
        if (_isSos) await _stopSos();
      },
      child: Scaffold(
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
                const Icon(Icons.flashlight_on, size: 72, color: Colors.amber),
                const SizedBox(height: 12),
                Text('Flash LED + Vibración + Sonido', style: theme.textTheme.bodyMedium),
                Text('Parpadeo SOS ··· −−− ···', style: theme.textTheme.bodyMedium),
                const SizedBox(height: 16),
                // Estado de dispositivos
                if (_torchChecked)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _statusChip('Flash', _torchOk),
                      const SizedBox(width: 8),
                      _statusChip('Sonido', _audioOk),
                      const SizedBox(width: 8),
                      _statusChip('Vibración', true),
                    ],
                  ),
                if (!_torchOk && _torchChecked)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text('Flash no disponible en este dispositivo\nSe usará pantalla blanca + vibración',
                      textAlign: TextAlign.center, style: theme.textTheme.bodySmall),
                  ),
                const SizedBox(height: 24),
              ] else ...[
                Text('S O S', style: theme.textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.bold, letterSpacing: 16)),
                const SizedBox(height: 8),
                Text('SEÑAL DE AUXILIO', style: theme.textTheme.titleMedium?.copyWith(letterSpacing: 4)),
                const SizedBox(height: 24),
                Icon(Icons.hearing, size: 48, color: _torchOk ? Colors.red : Colors.orange),
                const SizedBox(height: 8),
                Text(
                  _torchOk ? 'Flash LED + Vibración + Sonido' : 'Pantalla blanca + Vibración',
                  style: theme.textTheme.bodyMedium?.copyWith(color: _torchOk ? Colors.black87 : Colors.orange.shade700)),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: 220,
                height: 76,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isSos ? Colors.red : Colors.amber,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(36)),
                  ),
                  onPressed: _toggleSos,
                  autofocus: true,
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
              if (_feedback != null) ...[
                const SizedBox(height: 16),
                Text(_feedback!, style: theme.textTheme.bodySmall),
              ],
              if (!_isTorch)
                Padding(
                  padding: const EdgeInsets.only(top: 18),
                  child: Text('Al activar: flash LED parpadea en código Morse\n+ vibración + sonido de alarma',
                    textAlign: TextAlign.center, style: theme.textTheme.bodySmall),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusChip(String label, bool ok) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: ok ? Colors.green.shade50 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ok ? Colors.green : Colors.grey.shade300),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(ok ? Icons.check_circle : Icons.cancel, size: 14, color: ok ? Colors.green : Colors.grey),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 12, color: ok ? Colors.green.shade800 : Colors.grey.shade600)),
        ],
      ),
    );
  }
}