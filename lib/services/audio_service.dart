import 'package:audioplayers/audioplayers.dart';

class AudioService {
  AudioService._();
  static final AudioService instance = AudioService._();

  final AudioPlayer _player = AudioPlayer();
  bool _inited = false;

  bool get isPlaying => _player.state == PlayerState.playing;

  Future<void> init() async {
    if (_inited) return;
    _inited = true;
    await _player.setReleaseMode(ReleaseMode.loop); // 背景音乐循环
    await _player.setVolume(0.6);
  }

  Future<void> playBgm() async {
    await init();
    // 播放本地 asset 音频
    await _player.play(AssetSource('audio/bgm.mp3'));
  }

  Future<void> pause() async {
    await _player.pause();
  }

  Future<void> stop() async {
    await _player.stop();
  }

  Future<void> setVolume(double v) async {
    await _player.setVolume(v.clamp(0.0, 1.0));
  }

  void dispose() {
    _player.dispose();
  }
}
