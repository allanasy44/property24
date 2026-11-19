import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../routes/app_routes.dart';
import '../services/property24_api.dart';
import '../state/property24_state.dart';
import '../theme/app_theme.dart';
import '../widgets/inprop_brand.dart';

class EmailVerificationScreen extends StatefulWidget {
  const EmailVerificationScreen({super.key});

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  late final TextEditingController _email;
  final _code = TextEditingController();
  String? _challengeId;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _email = TextEditingController(
      text: context.read<Property24State>().user?.email ?? '',
    );
  }

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<Property24State>().user;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Sign in to verify your email.')),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(child: InPropBrand(size: 56)),
                  const SizedBox(height: 28),
                  Icon(
                    user.emailVerified ? Icons.mark_email_read_outlined : Icons.email_outlined,
                    color: AppTheme.accent,
                    size: 52,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    user.emailVerified ? 'Email verified' : 'Verify your email',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    user.emailVerified
                        ? 'Your email address is verified.'
                        : 'We’ll send a one-time code to your email address. You only need to verify it once.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppTheme.textMuted, height: 1.4),
                  ),
                  const SizedBox(height: 24),
                  if (user.emailVerified)
                    FilledButton(
                      onPressed: () => context.go(AppRoutes.homeScreen),
                      child: const Text('Continue to Property24'),
                    )
                  else ...[
                    TextField(
                      controller: _email,
                      enabled: !_busy && _challengeId == null,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email address',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    if (_challengeId != null) ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: _code,
                        enabled: !_busy,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        maxLength: 6,
                        decoration: const InputDecoration(
                          labelText: '6-digit email code',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _busy
                          ? null
                          : _challengeId == null
                          ? _requestCode
                          : _verifyCode,
                      child: _busy
                          ? const CircularProgressIndicator()
                          : Text(
                              _challengeId == null
                                  ? 'Send email code'
                                  : 'Verify email',
                            ),
                    ),
                    if (_challengeId != null)
                      TextButton(
                        onPressed: _busy ? null : _requestCode,
                        child: const Text('Send a new code'),
                      ),
                  ],
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () async {
                            await context.read<Property24State>().signOut();
                            if (context.mounted) {
                              context.go(AppRoutes.initial);
                            }
                          },
                    child: const Text('Sign out'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _requestCode() async {
    final email = _email.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = 'Enter a valid email address.');
      return;
    }
    await _run(() async {
      _challengeId = await context
          .read<Property24State>()
          .requestEmailVerification(email: email);
    });
  }

  Future<void> _verifyCode() async {
    final challengeId = _challengeId;
    if (challengeId == null) return;
    await _run(() async {
      await context.read<Property24State>().verifyEmail(
        challengeId,
        _code.text.trim(),
      );
      if (mounted) context.go(AppRoutes.homeScreen);
    });
  }

  Future<void> _run(Future<void> Function() operation) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await operation();
    } catch (exception) {
      if (mounted) setState(() => _error = userFacingError(exception));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
