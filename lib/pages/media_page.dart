import 'package:flutter/material.dart';
import '../services/audio_service.dart';

class MediaPage extends StatefulWidget {
  const MediaPage({super.key});

  @override
  State<MediaPage> createState() => _MediaPageState();
}

class _MediaPageState extends State<MediaPage> {
  final _audio = AudioService.instance;

  bool _playing = false;
  double _volume = 0.6;

  @override
  void initState() {
    super.initState();
    _audio.init();
  }

  Future<void> _toggle() async {
    if (_playing) {
      await _audio.pause();
    } else {
      await _audio.playBgm();
    }
    if (!mounted) return;
    setState(() => _playing = !_playing);
  }

  Future<void> _stop() async {
    await _audio.stop();
    if (!mounted) return;
    setState(() => _playing = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Media Player')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const SizedBox(height: 10),
            const Icon(Icons.music_note_rounded, size: 72),
            const SizedBox(height: 12),
            const Text(
              'Background Music (Asset)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _toggle,
                    icon: Icon(_playing ? Icons.pause : Icons.play_arrow),
                    label: Text(_playing ? 'Pause' : 'Play'),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton.filledTonal(
                  onPressed: _stop,
                  icon: const Icon(Icons.stop),
                ),
              ],
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                const Icon(Icons.volume_down),
                Expanded(
                  child: Slider(
                    value: _volume,
                    onChanged: (v) async {
                      setState(() => _volume = v);
                      await _audio.setVolume(v);
                    },
                  ),
                ),
                const Icon(Icons.volume_up),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Tip: This page proves Multimedia integration (audio playback).',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
