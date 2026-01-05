import 'package:flutter/material.dart';

import '../repositories/auth_repository.dart';
import '../services/audio_service.dart';
import 'media_page.dart';

class ProfilePage extends StatefulWidget {
  final int userId;
  final String username;

  const ProfilePage({super.key, required this.userId, required this.username});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _authRepo = AuthRepository();

  final AudioService _audio = AudioService.instance;

  // Available background music tracks (asset paths without 'assets/' prefix)
  final List<String> _tracks = const [
    'audio/bgm.mp3',
    'audio/bgm1.mp3',
    'audio/bgm2.mp3',
  ];

  String _selectedTrack = AudioService.defaultTrack;
  double _volume = AudioService.defaultVolume;
  bool _autoPlay = AudioService.defaultAutoPlay;
  bool _isPlaying = false;

  bool _loggingOut = false;
  bool _deleting = false;

  Future<void> _refreshAudioState() async {
    await _audio.init();
    setState(() {
      _selectedTrack = _audio.currentTrack;
      _volume = _audio.volume;
      _autoPlay = _audio.autoPlay;
      _isPlaying = _audio.isPlaying;
    });
  }

  Future<void> _openMusicSheet() async {
    await _refreshAudioState();
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            Future<void> syncState() async {
              setModalState(() {
                _selectedTrack = _audio.currentTrack;
                _volume = _audio.volume;
                _autoPlay = _audio.autoPlay;
                _isPlaying = _audio.isPlaying;
              });
            }

            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Background Music',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _selectedTrack,
                    decoration: const InputDecoration(
                      labelText: 'Select Track',
                      border: OutlineInputBorder(),
                    ),
                    items: _tracks
                        .map((t) => DropdownMenuItem(
                              value: t,
                              child: Text(t.split('/').last),
                            ))
                        .toList(),
                    onChanged: (v) async {
                      if (v == null) return;
                      await _audio.setTrack(v);
                      await syncState();
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () async {
                            if (_isPlaying) {
                              await _audio.pause();
                            } else {
                              await _audio.playCurrent();
                            }
                            await syncState();
                          },
                          icon:
                              Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                          label: Text(_isPlaying ? 'Pause' : 'Play'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      IconButton.filledTonal(
                        onPressed: () async {
                          await _audio.stop();
                          await syncState();
                        },
                        icon: const Icon(Icons.stop),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(Icons.volume_down),
                      Expanded(
                        child: Slider(
                          value: _volume,
                          onChanged: (v) async {
                            setModalState(() => _volume = v);
                            await _audio.setVolume(v);
                          },
                        ),
                      ),
                      const Icon(Icons.volume_up),
                    ],
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Auto play on app start'),
                    value: _autoPlay,
                    onChanged: (v) async {
                      await _audio.setAutoPlay(v);
                      await syncState();
                    },
                  ),
                  const SizedBox(height: 6),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.open_in_new_rounded),
                    title: const Text('Open Media Player'),
                    subtitle: const Text('Full controls and track list'),
                    onTap: () {
                      Navigator.pop(ctx);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const MediaPage()),
                      );
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    ).whenComplete(() async {
      // Refresh the profile page state when the sheet closes
      await _refreshAudioState();
    });
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _logout() async {
    if (_loggingOut || _deleting) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text('You will return to the sign-in screen.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    setState(() => _loggingOut = true);
    try {
      await _authRepo.logout();
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      _showSnack('Sign out failed: $e');
    } finally {
      if (mounted) setState(() => _loggingOut = false);
    }
  }

  Future<void> _deleteAccount() async {
    if (_loggingOut || _deleting) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete account?'),
        content: const Text(
          'This will delete your account and all memo data.\n'
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    setState(() => _deleting = true);
    try {
      await _authRepo.deleteAccount(userId: widget.userId);
      await _authRepo.logout();

      if (!mounted) return;
      _showSnack('Account deleted');
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      _showSnack('Delete failed: $e');
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: SafeArea(
        child: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    theme.colorScheme.primary.withOpacity(0.03), // light purple
                    Colors.blue.withOpacity(0.10), // light blue
                  ],
                ),
              ),
            ),
            ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
              children: [
                _UserCard(username: widget.username, userId: widget.userId),
                const SizedBox(height: 12),
                Card(
                  elevation: 0.8,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.info_outline_rounded),
                        title: const Text('About'),
                        subtitle: const Text(
                          'Assignment 2 - Private Memo (SQLite CRUD)',
                        ),
                        onTap: () {
                          showAboutDialog(
                            context: context,
                            applicationName: 'Private Memo',
                            applicationVersion: '1.0.0',
                            applicationLegalese: 'SWE311 Assignment 2',
                          );
                        },
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.privacy_tip_outlined),
                        title: const Text('Privacy'),
                        subtitle: const Text(
                          'All data is stored locally on this device.',
                        ),
                        onTap: () {
                          showModalBottomSheet(
                            context: context,
                            showDragHandle: true,
                            builder: (_) => Padding(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 22),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Privacy',
                                    style: theme.textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    '• Accounts and memos are stored locally using SQLite.\n'
                                    '• No internet connection is required.',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      height: 1.35,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  elevation: 0.8,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.logout_rounded),
                        title: const Text('Sign out'),
                        subtitle: const Text('Return to the sign-in screen'),
                        onTap: _loggingOut || _deleting ? null : _logout,
                        trailing: _loggingOut
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : null,
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: Icon(
                          Icons.delete_forever_rounded,
                          color: theme.colorScheme.error,
                        ),
                        title: Text(
                          'Delete account',
                          style: TextStyle(color: theme.colorScheme.error),
                        ),
                        subtitle: const Text(
                          'Delete account and all memos (irreversible)',
                        ),
                        onTap: _loggingOut || _deleting ? null : _deleteAccount,
                        trailing: _deleting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : null,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface.withOpacity(0.92),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: theme.colorScheme.outlineVariant.withOpacity(0.25),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.privacy_tip_rounded,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Tip: Signing in helps protect your private memos on this device.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  final String username;
  final int userId;

  const _UserCard({required this.username, required this.userId});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withOpacity(0.92),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withOpacity(0.25),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(
              Icons.person_rounded,
              color: theme.colorScheme.primary,
              size: 28,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  username,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  'User ID: $userId',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
