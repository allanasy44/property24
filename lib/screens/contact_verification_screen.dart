import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../routes/app_routes.dart';
import '../services/property24_api.dart';
import '../state/property24_state.dart';
import '../theme/app_theme.dart';
import '../widgets/inprop_brand.dart';

class ContactVerificationScreen extends StatefulWidget {
  const ContactVerificationScreen({super.key});

  @override
  State<ContactVerificationScreen> createState() =>
      _ContactVerificationScreenState();
}

class _ContactVerificationScreenState extends State<ContactVerificationScreen> {
  final _email = TextEditingController();
  final _emailCode = TextEditingController();
  final _phone = TextEditingController();
  final _phoneCode = TextEditingController();
  String? _emailChallengeId;
  String? _phoneChallengeId;
  String? _error;
  bool _busy = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final user = context.read<Property24State>().user;
    if (user != null) {
      if (_email.text.isEmpty) _email.text = user.email;
      if (_phone.text.isEmpty) _phone.text = user.phone;
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _emailCode.dispose();
    _phone.dispose();
    _phoneCode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<Property24State>();
    final user = state.user;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Sign in to verify your account.')),
      );
    }
    if (user.emailVerified && user.phoneVerified) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: FilledButton(
            onPressed: () => context.go(AppRoutes.homeScreen),
            child: const Text('Continue to Property24'),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: LayoutBuilder(
                      builder: (context, logoConstraints) {
                        const aspectRatio = 1360 / 420;
                        final logoSize =
                            logoConstraints.maxWidth < 56 * aspectRatio
                            ? logoConstraints.maxWidth / aspectRatio
                            : 56.0;
                        return InPropBrand(size: logoSize);
                      },
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Icon(
                    Icons.verified_user_outlined,
                    color: AppTheme.accent,
                    size: 52,
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Verify your contact details',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Confirm your email and phone to continue. Identity verification is handled separately in your account.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppTheme.textMuted, height: 1.4),
                  ),
                  const SizedBox(height: 24),
                  if (!user.emailVerified)
                    _verificationCard(
                      title: 'Email address',
                      controller: _email,
                      codeController: _emailCode,
                      challengeId: _emailChallengeId,
                      inputType: TextInputType.emailAddress,
                      inputLabel: 'Email address',
                      codeLabel: 'Email code',
                      requestLabel: _emailChallengeId == null
                          ? 'Send email code'
                          : 'Resend email code',
                      onRequest: _requestEmailCode,
                      onVerify: _verifyEmailCode,
                    )
                  else
                    _statusCard('Email address', user.email),
                  const SizedBox(height: 14),
                  if (!user.phoneVerified)
                    _verificationCard(
                      title: 'Phone number',
                      controller: _phone,
                      codeController: _phoneCode,
                      challengeId: _phoneChallengeId,
                      inputType: TextInputType.phone,
                      inputLabel: 'Zimbabwe phone number',
                      codeLabel: 'SMS code',
                      requestLabel: _phoneChallengeId == null
                          ? 'Send SMS code'
                          : 'Resend SMS code',
                      onRequest: _requestPhoneCode,
                      onVerify: _verifyPhoneCode,
                      phoneLocked: user.phone.trim().isNotEmpty,
                    )
                  else
                    _statusCard('Phone number', user.phone),
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppTheme.accent),
                    ),
                  ],
                  const SizedBox(height: 18),
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

  Widget _statusCard(String title, String value) {
    return Card(
      color: AppTheme.bgCard,
      child: ListTile(
        leading: const Icon(Icons.check_circle, color: AppTheme.accentTeal),
        title: Text(title, style: TextStyle(color: AppTheme.textPrimary)),
        subtitle: Text(value, style: TextStyle(color: AppTheme.textMuted)),
        trailing: const Text('Verified'),
      ),
    );
  }

  Widget _verificationCard({
    required String title,
    required TextEditingController controller,
    required TextEditingController codeController,
    required String? challengeId,
    required TextInputType inputType,
    required String inputLabel,
    required String codeLabel,
    required String requestLabel,
    required Future<void> Function() onRequest,
    required Future<void> Function() onVerify,
    bool phoneLocked = false,
  }) {
    return Card(
      color: AppTheme.bgCard,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              enabled: !_busy && !phoneLocked,
              keyboardType: inputType,
              style: TextStyle(color: AppTheme.textPrimary),
              decoration: InputDecoration(
                labelText: inputLabel,
                border: const OutlineInputBorder(),
              ),
            ),
            if (challengeId != null) ...[
              const SizedBox(height: 10),
              TextField(
                controller: codeController,
                enabled: !_busy,
                keyboardType: TextInputType.number,
                style: TextStyle(color: AppTheme.textPrimary),
                decoration: InputDecoration(
                  labelText: codeLabel,
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _busy ? null : onRequest,
              child: Text(requestLabel),
            ),
            if (challengeId != null)
              FilledButton(
                onPressed: _busy ? null : onVerify,
                child: const Text('Verify code'),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _requestEmailCode() async {
    final email = _email.text.trim();
    if (email.isEmpty) {
      setState(() => _error = 'Enter your email address.');
      return;
    }
    await _run(() async {
      _emailChallengeId = await context
          .read<Property24State>()
          .requestEmailVerification(email: email);
    });
  }

  Future<void> _verifyEmailCode() async {
    final challengeId = _emailChallengeId;
    if (challengeId == null) return;
    await _run(
      () => context.read<Property24State>().verifyEmail(
        challengeId,
        _emailCode.text.trim(),
      ),
    );
  }

  Future<void> _requestPhoneCode() async {
    final phone = _phone.text.trim();
    if (phone.isEmpty) {
      setState(() => _error = 'Enter your Zimbabwe phone number.');
      return;
    }
    await _run(() async {
      _phoneChallengeId = await context
          .read<Property24State>()
          .requestPhoneVerification(phone: phone);
    });
  }

  Future<void> _verifyPhoneCode() async {
    final challengeId = _phoneChallengeId;
    if (challengeId == null) return;
    await _run(
      () => context.read<Property24State>().verifyPhone(
        challengeId,
        _phoneCode.text.trim(),
      ),
    );
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
