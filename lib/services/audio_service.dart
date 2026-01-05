import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

/// Background music service (singleton).
///
/// Fixes for common issues:
/// - "Plays then randomly stops": set AudioContext + safe stop/play retry.
/// - "After stopping, play has no sound": reset state before play + retry.
/// - "Pause then play restarts from beginning": resume when paused & same track.
/// - "Change track while paused has no sound": detect track change and re-load asset.
///
/// NOTE:
/// AssetSource paths MUST NOT include 'assets/' prefix.
/// Example: assets/audio/Glass.mp3 -> 'audio/Glass.mp3'
class AudioService {
  AudioService._();
  static final AudioService instance = AudioService._();

  // Persist keys
  static const String _kSelectedTrack = 'bgm_selected_track';
  static const String _kVolume = 'bgm_volume';
  static const String _kAutoPlay = 'bgm_autoplay';

  // Defaults
  static const String defaultTrack = 'audio/bgm.mp3';
  static const double defaultVolume = 0.6;
  static const bool defaultAutoPlay = true;

  final AudioPlayer _player = AudioPlayer();
  bool _inited = false;

  // Track whether the user/app wants music playing.
  bool _desiredPlaying = false;
  bool _recovering = false;

  StreamSubscription<PlayerState>? _stateSub;
  StreamSubscription<void>? _completeSub;

  String _currentTrack = defaultTrack;
  String _lastPlayedTrack =
      defaultTrack; // last track actually loaded into player
  double _volume = defaultVolume;
  bool _autoPlay = defaultAutoPlay;

  // Getters
  String get currentTrack => _currentTrack;
  double get volume => _volume;
  bool get autoPlay => _autoPlay;

  bool get isPlaying => _player.state == PlayerState.playing;
  PlayerState get state => _player.state;

  /// Initialize player + load persisted settings (track/volume/autoplay).
  /// Safe to call multiple times.
  Future<void> init() async {
    if (_inited) return;
    _inited = true;

    await _player.setReleaseMode(ReleaseMode.loop);
    await _safeSetAudioContext();

    // Listen for unexpected stops/completions and try to recover if music is desired.
    _stateSub ??= _player.onPlayerStateChanged.listen((state) {
      if (_desiredPlaying &&
          (state == PlayerState.stopped || state == PlayerState.completed)) {
        _recoverIfNeeded();
      }
    });

    _completeSub ??= _player.onPlayerComplete.listen((_) {
      if (_desiredPlaying) {
        _recoverIfNeeded();
      }
    });

    final prefs = await SharedPreferences.getInstance();
    _currentTrack = prefs.getString(_kSelectedTrack) ?? defaultTrack;
    _lastPlayedTrack = _currentTrack;
    _volume = prefs.getDouble(_kVolume) ?? defaultVolume;
    _autoPlay = prefs.getBool(_kAutoPlay) ?? defaultAutoPlay;

    await _safeSetVolume(_volume);
  }

  /// Call after app bootstrap/login if you want to auto-play when enabled.
  Future<void> restoreAndMaybeAutoPlay() async {
    await init();
    if (_autoPlay) {
      await playCurrent();
    }
  }

  /// Persist selected track and optionally switch immediately.
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

  /// Play the current track.
  /// - If paused and track unchanged -> resume
  /// - Otherwise -> stop + play (fresh load)
  Future<void> playCurrent() async {
    await init();

    _desiredPlaying = true;

    final pausedSameTrack = _player.state == PlayerState.paused &&
        _lastPlayedTrack == _currentTrack;

    if (pausedSameTrack) {
      await _safeResume();
      return;
    }

    // Reset state first (helps recover after interruptions / no-sound bug)
    await _safeStop();

    // Small delay helps some devices recover audio focus after route changes
    await Future<void>.delayed(const Duration(milliseconds: 80));

    await _safePlayAsset(_currentTrack);
    _lastPlayedTrack = _currentTrack;
  }

  /// Used by UI: if paused -> resume; else -> play current (from start).
  Future<void> resumeOrPlayCurrent() async {
    await init();

    _desiredPlaying = true;

    final pausedSameTrack = _player.state == PlayerState.paused &&
        _lastPlayedTrack == _currentTrack;

    if (pausedSameTrack) {
      await _safeResume();
      return;
    }

    await playCurrent();
  }

  Future<void> pause() async {
    await init();

    _desiredPlaying = false;
    try {
      await _player.pause();
    } catch (_) {}
  }

  Future<void> stop() async {
    await init();

    _desiredPlaying = false;
    await _safeStop();
  }

  Future<void> setVolume(double v) async {
    await init();
    _volume = v.clamp(0.0, 1.0);

    await _safeSetVolume(_volume);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kVolume, _volume);
  }

  Future<void> setAutoPlay(bool value) async {
    await init();
    _autoPlay = value;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kAutoPlay, _autoPlay);
  }

  // =========================
  // Internal "safe" helpers
  // =========================

  Future<void> _safePlayAsset(String assetPath) async {
    try {
      await _player.play(AssetSource(assetPath));
      return;
    } catch (_) {}

    // Retry after re-applying audio context
    try {
      await _safeSetAudioContext();
      await _player.play(AssetSource(assetPath));
    } catch (_) {}
  }

  Future<void> _safeStop() async {
    try {
      await _player.stop();
    } catch (_) {}
  }

  Future<void> _safeResume() async {
    try {
      await _player.resume();
      return;
    } catch (_) {}

    // If resume fails (e.g., focus loss), re-load current asset
    await _safeStop();
    await Future<void>.delayed(const Duration(milliseconds: 80));
    await _safePlayAsset(_currentTrack);
  }

  Future<void> _safeSetVolume(double v) async {
    try {
      await _player.setVolume(v);
    } catch (_) {}
  }

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
    } catch (_) {}
  }

  Future<void> _recoverIfNeeded() async {
    if (_recovering) return;
    _recovering = true;
    try {
      // Give the system a moment to restore audio focus after interruptions.
      await Future<void>.delayed(const Duration(milliseconds: 120));
      await _safeSetAudioContext();

      // If paused on same track, try resume; otherwise re-load current asset.
      if (_player.state == PlayerState.paused &&
          _lastPlayedTrack == _currentTrack) {
        await _safeResume();
      } else if (_desiredPlaying) {
        await _safeStop();
        await Future<void>.delayed(const Duration(milliseconds: 80));
        await _safePlayAsset(_currentTrack);
        _lastPlayedTrack = _currentTrack;
      }
    } finally {
      _recovering = false;
    }
  }

  void dispose() {
    _stateSub?.cancel();
    _completeSub?.cancel();
    _player.dispose();
  }
}
