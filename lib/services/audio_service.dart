import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A singleton service that manages background music playback
/// and persists the user's selected track (asset) + volume.
///
/// This version also sets an AudioContext to reduce "plays then suddenly stops"
/// issues caused by audio focus changes, and resets the player before replaying.
class AudioService {
  AudioService._();
  static final AudioService instance = AudioService._();

  // ===== Persist keys =====
  static const String _kSelectedTrack = 'bgm_selected_track';
  static const String _kVolume = 'bgm_volume';
  static const String _kAutoPlay = 'bgm_autoplay';

  // ===== Defaults =====
  /// IMPORTANT: AssetSource path should NOT include "assets/" prefix.
  /// If your asset is assets/audio/bgm1.mp3, use "audio/bgm1.mp3".
  static const String defaultTrack = 'audio/bgm.mp3';
  static const double defaultVolume = 0.6;
  static const bool defaultAutoPlay = true;

  final AudioPlayer _player = AudioPlayer();
  bool _inited = false;

  String _currentTrack = defaultTrack;
  double _volume = defaultVolume;
  bool _autoPlay = defaultAutoPlay;

  // Track actually loaded/played in the player last time.
  String _lastPlayedTrack = defaultTrack;

  // ===== Public getters =====
  String get currentTrack => _currentTrack;
  double get volume => _volume;
  bool get autoPlay => _autoPlay;

  bool get isPlaying => _player.state == PlayerState.playing;

  PlayerState get state => _player.state;

  // ===== Init / Restore =====
  /// Initializes player + loads persisted settings (track/volume/autoplay).
  /// Safe to call multiple times.
  Future<void> init() async {
    if (_inited) return;
    _inited = true;

    // Loop background music
    await _player.setReleaseMode(ReleaseMode.loop);

    // Reduce random stops by configuring audio focus / usage as "media/music".
    // (If some platforms ignore this, it won't break playback.)
    await _safeSetAudioContext();

    final prefs = await SharedPreferences.getInstance();
    _currentTrack = prefs.getString(_kSelectedTrack) ?? defaultTrack;
    _volume = prefs.getDouble(_kVolume) ?? defaultVolume;
    _autoPlay = prefs.getBool(_kAutoPlay) ?? defaultAutoPlay;

    await _player.setVolume(_volume);
  }

  /// Loads saved track/volume/autoplay and starts playing if autoPlay==true.
  /// Call this from main.dart (after login or app bootstrap).
  Future<void> restoreAndMaybeAutoPlay() async {
    await init();
    if (_autoPlay) {
      await playCurrent();
    }
  }

  // ===== Track selection =====
  /// Set current track (asset path) and persist it.
  /// Optionally switch immediately (recommended for "Change Music" action).
  Future<void> setTrack(
    String assetPath, {
    bool switchImmediately = true,
  }) async {
    await init();
    _currentTrack = assetPath;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kSelectedTrack, _currentTrack);

    if (switchImmediately) {
      await playCurrent();
    }
  }

  /// Plays currently selected track (looping).
  ///
  /// IMPORTANT: We stop() before play() to avoid a stuck internal state after
  /// audio focus interruptions (common cause of "no sound when pressing play").
  Future<void> playCurrent() async {
    await init();

    // If we're paused, only resume when it's the same track as last played.
    // If the user changed tracks while paused, we must load the new asset.
    if (_player.state == PlayerState.paused &&
        _lastPlayedTrack == _currentTrack) {
      await _player.resume();
      return;
    }

    // Reset state first (helps recover after interruptions)
    try {
      await _player.stop();
    } catch (_) {}

    try {
      await _player.play(AssetSource(_currentTrack));
      _lastPlayedTrack = _currentTrack;
    } catch (_) {
      // One retry after re-applying audio context (defensive)
      await _safeSetAudioContext();
      await _player.play(AssetSource(_currentTrack));
      _lastPlayedTrack = _currentTrack;
    }
  }

  /// Resume playback if paused; otherwise play current track from the start.
  Future<void> resumeOrPlayCurrent() async {
    await init();
    if (_player.state == PlayerState.paused) {
      await _player.resume();
      return;
    }
    await playCurrent();
  }

  /// Resume playback (only meaningful if paused).
  Future<void> resume() async {
    await init();
    if (_player.state == PlayerState.paused) {
      await _player.resume();
    }
  }

  /// Convenience:  /// Convenience: play a specific asset immediately (also sets as current & persists).
  Future<void> playAsset(String assetPath) async {
    await setTrack(assetPath, switchImmediately: true);
  }

  // ===== Playback controls =====
  Future<void> pause() async {
    await init();
    await _player.pause();
  }

  Future<void> stop() async {
    await init();
    await _player.stop();
  }

  // ===== Settings =====
  Future<void> setVolume(double v) async {
    await init();
    _volume = v.clamp(0.0, 1.0);

    await _player.setVolume(_volume);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kVolume, _volume);
  }

  /// Persist autoplay preference (whether to auto-play on app start/login).
  Future<void> setAutoPlay(bool value) async {
    await init();
    _autoPlay = value;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kAutoPlay, _autoPlay);
  }

  /// Configure audio focus / usage to be "media/music".
  Future<void> _safeSetAudioContext() async {
    try {
      await _player.setAudioContext(
        AudioContext(
          android: AudioContextAndroid(
            contentType: AndroidContentType.music,
            usageType: AndroidUsageType.media,
            audioFocus: AndroidAudioFocus.gain,
            stayAwake: true,
          ),
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.playback,
            options: const {
              AVAudioSessionOptions.mixWithOthers,
            },
          ),
        ),
      );
    } catch (_) {
      // Ignore if platform / version doesn't support some fields.
    }
  }

  void dispose() {
    _player.dispose();
  }
}
