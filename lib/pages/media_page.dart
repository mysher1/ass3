import 'package:flutter/material.dart';
import '../services/audio_service.dart';

class MediaPage extends StatefulWidget {
  const MediaPage({super.key});

  @override
  State<MediaPage> createState() => _MediaPageState();
}

class _MediaPageState extends State<MediaPage> with WidgetsBindingObserver {
  final AudioService _audio = AudioService.instance;

  late final List<String> _tracks;

  bool _isPlaying = false;
  double _volume = AudioService.defaultVolume;
  bool _autoPlay = AudioService.defaultAutoPlay;
  String _selectedTrack = AudioService.defaultTrack;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _tracks = <String>[
      'audio/black.mp3',
      'audio/Compass.mp3',
      'audio/Glass.mp3',
    ];

    _initState();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.resumed) {
      setState(() {
        _isPlaying = _audio.isPlaying;
      });
    }
  }

  Future<void> _initState() async {
    await _audio.init();

    final savedTrack = _audio.currentTrack;
    if (savedTrack.isNotEmpty && !_tracks.contains(savedTrack)) {
      _tracks.insert(0, savedTrack);
    }

    if (!mounted) return;
    setState(() {
      _selectedTrack = _tracks.contains(savedTrack)
          ? savedTrack
          : (_tracks.isNotEmpty ? _tracks.first : AudioService.defaultTrack);
      _volume = _audio.volume;
      _autoPlay = _audio.autoPlay;
      _isPlaying = _audio.isPlaying;
    });
  }

  Future<void> _onTrackChanged(String? value) async {
    if (value == null) return;
    await _audio.setTrack(value);
    if (!mounted) return;
    setState(() {
      _selectedTrack = value;
      _isPlaying = _audio.isPlaying;
    });
  }

  Future<void> _togglePlay() async {
    if (_isPlaying) {
      await _audio.pause();
    } else {
      await _audio.resumeOrPlayCurrent();
    }
    if (!mounted) return;
    setState(() => _isPlaying = _audio.isPlaying);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Media Player')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Background Music',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                'Current: ${_selectedTrack.split('/').last}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _selectedTrack,
                decoration: const InputDecoration(
                  labelText: 'Select Track',
                  border: OutlineInputBorder(),
                ),
                items: _tracks
                    .map(
                      (t) => DropdownMenuItem(
                        value: t,
                        child: Text(t.split('/').last),
                      ),
                    )
                    .toList(),
                onChanged: _onTrackChanged,
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _togglePlay,
                      icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                      label: Text(_isPlaying ? 'Pause' : 'Play'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
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
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Auto play on app start'),
                value: _autoPlay,
                onChanged: (v) async {
                  await _audio.setAutoPlay(v);
                  if (!mounted) return;
                  setState(() => _autoPlay = v);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
