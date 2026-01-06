// lib/pages/login_page.dart
import 'package:flutter/material.dart';

import '../repositories/auth_repository.dart';
import '../services/audio_service.dart';
import 'home_page.dart';
import 'signup_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _authRepo = AuthRepository();

  final _formKey = GlobalKey<FormState>();
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool _obscure = true;
  bool _loading = false;

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    FocusScope.of(context).unfocus();

    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) return;

    setState(() => _loading = true);

    try {
      final username = _usernameCtrl.text.trim();
      final password = _passwordCtrl.text;

      /// Contract: AuthRepository.login returns the logged-in userId (int).
      final int userId = await _authRepo.login(
        username: username,
        password: password,
      );

      if (!mounted) return;

      // Success: go to Home (pushReplacement prevents going back to Login).
      await Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => HomePage(userId: userId, username: username),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      _showSnack(_friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _friendlyError(Object e) {
    final msg = e.toString();

    // Keep these keywords aligned with what AuthRepository throws.
    if (msg.contains('User not found')) {
      return 'Account not found. Please sign up first.';
    }
    if (msg.contains('Wrong password')) {
      return 'Incorrect password. Please try again.';
    }
    if (msg.contains('Invalid')) {
      return 'Invalid username or password.';
    }
    return 'Sign in failed: $msg';
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _goSignup() async {
    FocusScope.of(context).unfocus();

    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const SignupPage()),
    );

    if (created == true && mounted) {
      _showSnack('Account created. Please sign in.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            // Subtle background (purple -> blue)
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    theme.colorScheme.primary.withOpacity(0.03),
                    theme.colorScheme.surface,
                    Colors.blue.shade300.withOpacity(0.10),
                  ],
                ),
              ),
            ),

            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _Header(theme: theme),
                      const SizedBox(height: 18),
                      Card(
                        elevation: 0.8,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              children: [
                                TextFormField(
                                  controller: _usernameCtrl,
                                  textInputAction: TextInputAction.next,
                                  keyboardType: TextInputType.text,
                                  decoration: InputDecoration(
                                    labelText: 'Username',
                                    hintText: 'Enter your username',
                                    prefixIcon: const Icon(
                                      Icons.person_rounded,
                                    ),
                                    border: const OutlineInputBorder(),
                                    filled: true,
                                    fillColor: theme
                                        .colorScheme.surfaceContainerHighest
                                        .withOpacity(0.1),
                                  ),
                                  validator: (v) {
                                    final s = (v ?? '').trim();
                                    if (s.isEmpty)
                                      return 'Please enter a username';
                                    if (s.length < 3) {
                                      return 'Username must be at least 3 characters';
                                    }
                                    if (s.length > 20) {
                                      return 'Username must be ≤ 20 characters';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _passwordCtrl,
                                  textInputAction: TextInputAction.done,
                                  obscureText: _obscure,
                                  onFieldSubmitted: (_) =>
                                      _loading ? null : _login(),
                                  decoration: InputDecoration(
                                    labelText: 'Password',
                                    hintText: 'Enter your password',
                                    prefixIcon: const Icon(Icons.lock_rounded),
                                    border: const OutlineInputBorder(),
                                    filled: true,
                                    fillColor: theme
                                        .colorScheme.surfaceContainerHighest
                                        .withOpacity(0.1),
                                    suffixIcon: IconButton(
                                      tooltip: _obscure
                                          ? 'Show password'
                                          : 'Hide password',
                                      onPressed: () =>
                                          setState(() => _obscure = !_obscure),
                                      icon: Icon(
                                        _obscure
                                            ? Icons.visibility_rounded
                                            : Icons.visibility_off_rounded,
                                      ),
                                    ),
                                  ),
                                  validator: (v) {
                                    final s = v ?? '';
                                    if (s.isEmpty)
                                      return 'Please enter a password';
                                    if (s.length < 6) {
                                      return 'Password must be at least 6 characters';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 14),
                                SizedBox(
                                  height: 48,
                                  width: double.infinity,
                                  child: FilledButton.icon(
                                    onPressed: _loading ? null : _login,
                                    icon: _loading
                                        ? const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Icon(Icons.login_rounded),
                                    label: Text(
                                      _loading ? 'Signing in…' : 'Sign in',
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      "Don't have an account?",
                                      style:
                                          theme.textTheme.bodyMedium?.copyWith(
                                        color:
                                            theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: _loading ? null : _goSignup,
                                      child: const Text('Create one'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _TipCard(theme: theme),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final ThemeData theme;
  const _Header({required this.theme});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.55),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.75),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              Icons.sticky_note_2_rounded,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Private Memo',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Sign in to access your private memos.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.3,
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

class _TipCard extends StatelessWidget {
  final ThemeData theme;
  const _TipCard({required this.theme});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
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
          Icon(Icons.privacy_tip_rounded, color: theme.colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Note: This app stores accounts and memos locally on your device (SQLite). '
              'No internet required.\n'
              'You can sign out from the Profile page.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Wrapper that triggers background-music auto-play after a successful login.
class _HomeWithAutoplay extends StatefulWidget {
  final int userId;
  final String username;

  const _HomeWithAutoplay({
    required this.userId,
    required this.username,
  });

  @override
  State<_HomeWithAutoplay> createState() => _HomeWithAutoplayState();
}

class _HomeWithAutoplayState extends State<_HomeWithAutoplay> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await AudioService.instance.restoreAndMaybeAutoPlay();
    });
  }

  @override
  Widget build(BuildContext context) {
    return HomePage(userId: widget.userId, username: widget.username);
  }
}
