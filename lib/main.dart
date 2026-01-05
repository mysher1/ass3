// lib/main.dart
import 'package:flutter/material.dart';

import 'pages/login_page.dart';
import 'pages/home_page.dart';
import 'repositories/auth_repository.dart';
import 'services/audio_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Private Memo',
      debugShowCheckedModeBanner: false,

      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.deepPurple,
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF6F2FF),
        appBarTheme: const AppBarTheme(elevation: 0, scrolledUnderElevation: 0),
        cardTheme: CardThemeData(
          elevation: 0.8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          margin: EdgeInsets.zero,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
        ),
      ),

      // Lock text scale
      builder: (context, child) {
        final mediaQuery = MediaQuery.of(context);
        return MediaQuery(
          data: mediaQuery.copyWith(textScaleFactor: 1.0),
          child: child!,
        );
      },

      home: const _BootstrapPage(),
    );
  }
}

/// Bootstrap page:
/// decides whether to go to Login or Home
class _BootstrapPage extends StatefulWidget {
  const _BootstrapPage();

  @override
  State<_BootstrapPage> createState() => _BootstrapPageState();
}

class _BootstrapPageState extends State<_BootstrapPage> {
  final _authRepo = AuthRepository();
  bool _loading = true;

  int? _userId;
  String? _username;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      // Prepare audio service (loads saved track/volume, sets audio context)
      await AudioService.instance.init();
      final userId = await _authRepo.getCurrentUserId();
      final username = await _authRepo.getCurrentUsername();

      // Auto-restore & play last selected background music after login
      if (userId != null && username != null && username.trim().isNotEmpty) {
        await AudioService.instance.restoreAndMaybeAutoPlay();
      }

      if (!mounted) return;
      setState(() {
        _userId = userId;
        _username = username;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const _Splash();
    }

    // Logged in → Home
    if (_userId != null && _username != null && _username!.trim().isNotEmpty) {
      return HomePage(userId: _userId!, username: _username!);
    }

    // Not logged in → Login
    return const LoginPage();
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.sticky_note_2_rounded,
              size: 54,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 14),
            const CircularProgressIndicator(),
            const SizedBox(height: 14),
            Text(
              'Loading your workspace...',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
