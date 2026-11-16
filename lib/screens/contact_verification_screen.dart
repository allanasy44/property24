import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../routes/app_routes.dart';
import '../services/property24_api.dart';
import '../state/property24_state.dart';
import '../theme/app_theme.dart';
import '../widgets/inprop_brand.dart';

const _verificationCardColor = Colors.white;
const _verificationFieldColor = Color(0xfff4f4f8);
const _verificationBorderColor = Color(0xffe8e8f4);
const _verificationTextColor = Color(0xff1f1e18);
const _verificationSecondaryTextColor = Color(0xff5f5f59);
const _verificationMutedTextColor = Color(0xff8b8b86);

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
    final phoneOnly = user.emailVerified && !user.phoneVerified;
    if (user.emailVerified && user.phoneVerified) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const InPropBrand(size: 56),
                  const SizedBox(height: 28),
                  const Icon(
                    Icons.verified_outlined,
                    color: AppTheme.accentTeal,
                    size: 52,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Your contact details are verified',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _verificationTextColor,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 22),
                  FilledButton(
                    onPressed: () => context.go(AppRoutes.homeScreen),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.accent,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Continue to Property24'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (phoneOnly) return _phoneVerificationScreen(user.email);

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
                    Icons.phone_android_outlined,
                    color: AppTheme.accent,
                    size: 52,
                  ),
                  const SizedBox(height: 18),
                  Text(
                    phoneOnly
                        ? 'Verify your phone number'
                        : 'Verify your contact details',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    phoneOnly
                        ? 'Enter your mobile number and we’ll text you a code to confirm it.'
                        : 'Confirm your email and phone to continue. Identity verification is handled separately in your account.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppTheme.textMuted, height: 1.4),
                  ),
                  const SizedBox(height: 24),
                  if (!phoneOnly && !user.emailVerified)
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
                  else if (!phoneOnly)
                    _statusCard('Email address', user.email),
                  const SizedBox(height: 14),
                  if (!user.phoneVerified)
                    _verificationCard(
                      title: 'Phone number',
                      controller: _phone,
                      codeController: _phoneCode,
                      challengeId: _phoneChallengeId,
                      inputType: TextInputType.phone,
                      inputLabel: 'Zimbabwe mobile number',
                      codeLabel: '6-digit SMS code',
                      requestLabel: _phoneChallengeId == null
                          ? 'Send code by SMS'
                          : 'Resend code by SMS',
                      onRequest: _requestPhoneCode,
                      onVerify: _verifyPhoneCode,
                      verifyLabel: 'Verify phone number',
                      phoneLocked:
                          user.phone.trim().isNotEmpty ||
                          _phoneChallengeId != null,
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

  Widget _phoneVerificationScreen(String email) {
    final codeRequested = _phoneChallengeId != null;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => Stack(
            fit: StackFit.expand,
            children: [
              SingleChildScrollView(
                padding: EdgeInsets.only(
                  top: 24,
                  left: 20,
                  right: 20,
                  bottom: MediaQuery.viewInsetsOf(context).bottom + 24,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - 48,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 460),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 28,
                          vertical: 24,
                        ),
                        decoration: BoxDecoration(
                          color: _verificationCardColor,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: _verificationBorderColor),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0x12000000),
                              blurRadius: 24,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Center(
                              child: LayoutBuilder(
                                builder: (context, logoConstraints) {
                                  const aspectRatio = 1360 / 420;
                                  const maxLogoSize = 112.0;
                                  final logoSize =
                                      logoConstraints.maxWidth <
                                          maxLogoSize * aspectRatio
                                      ? logoConstraints.maxWidth / aspectRatio
                                      : maxLogoSize;
                                  return InPropBrand(size: logoSize);
                                },
                              ),
                            ),
                            const SizedBox(height: 22),
                            Center(
                              child: Container(
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  color: AppTheme.accent.withAlpha(18),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.phone_iphone_rounded,
                                  color: AppTheme.accent,
                                  size: 25,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Verify your phone number',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: _verificationTextColor,
                                fontSize: 25,
                                height: 1.2,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              codeRequested
                                  ? 'Enter the 6-digit code we sent by SMS to verify your account.'
                                  : 'One last step. Add your mobile number and we’ll text you a verification code.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: _verificationSecondaryTextColor,
                                fontSize: 13,
                                height: 1.45,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              email,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: _verificationMutedTextColor,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 22),
                            TextField(
                              controller: _phone,
                              enabled: !_busy && !codeRequested,
                              keyboardType: TextInputType.phone,
                              style: const TextStyle(
                                color: _verificationTextColor,
                              ),
                              decoration: _verificationInputDecoration(
                                hintText: 'Zimbabwe mobile number',
                                prefixIcon: const Icon(
                                  Icons.phone_outlined,
                                  size: 19,
                                ),
                              ),
                            ),
                            if (codeRequested) ...[
                              const SizedBox(height: 12),
                              TextField(
                                controller: _phoneCode,
                                enabled: !_busy,
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.center,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                maxLength: 6,
                                style: const TextStyle(
                                  color: _verificationTextColor,
                                  fontSize: 20,
                                  letterSpacing: 8,
                                  fontWeight: FontWeight.w600,
                                ),
                                decoration: _verificationInputDecoration(
                                  hintText: '••••••',
                                  labelText: '6-digit SMS code',
                                  counterText: '',
                                  prefixIcon: const Icon(
                                    Icons.lock_outline,
                                    size: 19,
                                  ),
                                ),
                              ),
                            ],
                            if (_error != null) ...[
                              const SizedBox(height: 10),
                              Text(
                                _error!,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                            const SizedBox(height: 18),
                            SizedBox(
                              height: 46,
                              child: FilledButton(
                                onPressed: _busy
                                    ? null
                                    : codeRequested
                                    ? _verifyPhoneCode
                                    : _requestPhoneCode,
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppTheme.accent,
                                  foregroundColor: Colors.white,
                                ),
                                child: _busy
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : Text(
                                        codeRequested
                                            ? 'Verify phone number'
                                            : 'Send verification code',
                                      ),
                              ),
                            ),
                            if (codeRequested) ...[
                              const SizedBox(height: 4),
                              TextButton(
                                onPressed: _busy ? null : _requestPhoneCode,
                                style: TextButton.styleFrom(
                                  foregroundColor: AppTheme.accent,
                                ),
                                child: const Text('Resend code'),
                              ),
                            ],
                            const SizedBox(height: 4),
                            TextButton(
                              onPressed: _busy
                                  ? null
                                  : () async {
                                      await context
                                          .read<Property24State>()
                                          .signOut();
                                      if (context.mounted) {
                                        context.go(AppRoutes.initial);
                                      }
                                    },
                              style: TextButton.styleFrom(
                                foregroundColor: AppTheme.accent,
                              ),
                              child: const Text('Use a different account'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _verificationInputDecoration({
    String? hintText,
    String? labelText,
    String? counterText,
    required Widget prefixIcon,
  }) {
    const border = OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(8)),
      borderSide: BorderSide(color: _verificationBorderColor),
    );
    return InputDecoration(
      hintText: hintText,
      labelText: labelText,
      counterText: counterText,
      prefixIcon: prefixIcon,
      filled: true,
      fillColor: _verificationFieldColor,
      hintStyle: const TextStyle(color: _verificationMutedTextColor),
      labelStyle: const TextStyle(color: _verificationSecondaryTextColor),
      prefixIconColor: _verificationSecondaryTextColor,
      border: border,
      enabledBorder: border,
      disabledBorder: border,
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(8)),
        borderSide: BorderSide(color: AppTheme.accent, width: 1.4),
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
    String verifyLabel = 'Verify code',
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
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                maxLength: 6,
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
                child: Text(verifyLabel),
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
