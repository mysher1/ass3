// lib/pages/signup_page.dart
import 'package:flutter/material.dart';

import '../repositories/auth_repository.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final _authRepo = AuthRepository();

  final _formKey = GlobalKey<FormState>();
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _obscure1 = true;
  bool _obscure2 = true;
  bool _loading = false;

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _signup() async {
    FocusScope.of(context).unfocus();

    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) return;

    setState(() => _loading = true);

    try {
      final username = _usernameCtrl.text.trim();
      final password = _passwordCtrl.text;
      final confirm = _confirmCtrl.text;

      await _authRepo.signup(
        username: username,
        password: password,
        confirmPassword: confirm,
      );

      if (!mounted) return;

      // Success: return to LoginPage, notify previous page
      Navigator.pop(context, true);
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
    if (msg.contains('Username already exists')) {
      return 'Username already exists. Try another one.';
    }
    if (msg.contains('Invalid username')) {
      return 'Invalid username (3–20 characters).';
    }
    if (msg.contains('Invalid password')) {
      return 'Invalid password (at least 6 characters).';
    }
    if (msg.contains('Password not match')) return 'Passwords do not match.';
    return 'Sign up failed: $msg';
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Create account')),
      body: SafeArea(
        child: Stack(
          children: [
            // Subtle background
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    // make the top purple lighter
                    theme.colorScheme.primary.withOpacity(0.03),
                    theme.colorScheme.surface,
                    // bottom to blue
                    Colors.blue.shade300.withOpacity(0.10),
                  ],
                ),
              ),
            ),

            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _Header(theme: theme),
                      const SizedBox(height: 14),

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
                                  decoration: InputDecoration(
                                    labelText: 'Username',
                                    hintText: '3–20 characters',
                                    prefixIcon: const Icon(
                                      Icons.person_add_alt_1_rounded,
                                    ),
                                    border: const OutlineInputBorder(),
                                    filled: true,
                                    fillColor: theme
                                        .colorScheme
                                        .surfaceContainerHighest
                                        .withOpacity(0.45),
                                  ),
                                  validator: (v) {
                                    final s = (v ?? '').trim();
                                    if (s.isEmpty) {
                                      return 'Please enter a username';
                                    }
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
                                  textInputAction: TextInputAction.next,
                                  obscureText: _obscure1,
                                  decoration: InputDecoration(
                                    labelText: 'Password',
                                    hintText: 'At least 6 characters',
                                    prefixIcon: const Icon(Icons.lock_rounded),
                                    border: const OutlineInputBorder(),
                                    filled: true,
                                    fillColor: theme
                                        .colorScheme
                                        .surfaceContainerHighest
                                        .withOpacity(0.35),
                                    suffixIcon: IconButton(
                                      tooltip: _obscure1
                                          ? 'Show password'
                                          : 'Hide password',
                                      onPressed: () => setState(
                                        () => _obscure1 = !_obscure1,
                                      ),
                                      icon: Icon(
                                        _obscure1
                                            ? Icons.visibility_rounded
                                            : Icons.visibility_off_rounded,
                                      ),
                                    ),
                                  ),
                                  validator: (v) {
                                    final s = v ?? '';
                                    if (s.isEmpty) {
                                      return 'Please enter a password';
                                    }
                                    if (s.length < 6) {
                                      return 'Password must be at least 6 characters';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 12),

                                TextFormField(
                                  controller: _confirmCtrl,
                                  textInputAction: TextInputAction.done,
                                  obscureText: _obscure2,
                                  onFieldSubmitted: (_) =>
                                      _loading ? null : _signup(),
                                  decoration: InputDecoration(
                                    labelText: 'Confirm password',
                                    hintText: 'Re-enter your password',
                                    prefixIcon: const Icon(
                                      Icons.verified_user_rounded,
                                    ),
                                    border: const OutlineInputBorder(),
                                    filled: true,
                                    fillColor: theme
                                        .colorScheme
                                        .surfaceContainerHighest
                                        .withOpacity(0.35),
                                    suffixIcon: IconButton(
                                      tooltip: _obscure2
                                          ? 'Show password'
                                          : 'Hide password',
                                      onPressed: () => setState(
                                        () => _obscure2 = !_obscure2,
                                      ),
                                      icon: Icon(
                                        _obscure2
                                            ? Icons.visibility_rounded
                                            : Icons.visibility_off_rounded,
                                      ),
                                    ),
                                  ),
                                  validator: (v) {
                                    final s = v ?? '';
                                    if (s.isEmpty) {
                                      return 'Please confirm your password';
                                    }
                                    if (s != _passwordCtrl.text) {
                                      return 'Passwords do not match';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 14),

                                SizedBox(
                                  height: 48,
                                  width: double.infinity,
                                  child: FilledButton.icon(
                                    onPressed: _loading ? null : _signup,
                                    icon: _loading
                                        ? const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Icon(Icons.how_to_reg_rounded),
                                    label: Text(
                                      _loading ? 'Creating…' : 'Create account',
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      'Already have an account?',
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            color: theme
                                                .colorScheme
                                                .onSurfaceVariant,
                                          ),
                                    ),
                                    TextButton(
                                      onPressed: _loading
                                          ? null
                                          : () => Navigator.pop(context, false),
                                      child: const Text('Sign in'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 14),
                      _HintCard(theme: theme),
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
              Icons.person_add_alt_1_rounded,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Create a local account',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'This account protects your private memos (no internet required).',
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

class _HintCard extends StatelessWidget {
  final ThemeData theme;
  const _HintCard({required this.theme});

  @override
  Widget build(BuildContext context) {
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
              'Note: Accounts and memos are stored locally in an on-device SQLite database.\n'
              'Passwords are stored as SHA-256 hashes (never saved in plain text).',
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
