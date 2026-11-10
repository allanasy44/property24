import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/rental_models.dart';
import '../routes/app_routes.dart';
import '../services/property24_api.dart';
import '../state/property24_state.dart';
import '../theme/app_theme.dart';
import '../widgets/inprop_brand.dart';
import '../widgets/google_web_sign_in_button.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({
    required this.role,
    this.initialIntent = 'explore',
    super.key,
  });

  final AccountRole role;
  final String initialIntent;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _emailFocusNode = FocusNode();
  final _password = TextEditingController();
  final _passwordFocusNode = FocusNode();
  final _emailCode = TextEditingController();
  bool _registering = false;
  bool _showForm = false;
  bool _obscurePassword = true;
  bool _submitting = false;
  String? _registrationChallengeId;
  String? _error;
  Timer? _resendTimer;
  int _resendSeconds = 0;
  bool _phoneLogin = false;
  String _phoneCountry = 'ZW';
  String? _phoneChallengeId;
  String _maskedDestination = '';
  final _phone = TextEditingController();
  final _phoneCode = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _emailFocusNode.dispose();
    _password.dispose();
    _passwordFocusNode.dispose();
    _resendTimer?.cancel();
    _emailCode.dispose();
    _phone.dispose();
    _phoneCode.dispose();
    super.dispose();
  }

  List<String> get _propertyListingCapability =>
      widget.initialIntent == 'list-property' &&
          widget.role != AccountRole.admin
      ? const ['list_properties']
      : const [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Stack(
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
                            vertical: 30,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.bgCard.withAlpha(242),
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(
                              color: AppTheme.border.withAlpha(210),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withAlpha(30),
                                blurRadius: 36,
                                offset: const Offset(0, 18),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const InPropBrand(showWordmark: false, size: 80),
                              const SizedBox(height: 26),
                              if (_showForm)
                                _formContent()
                              else
                                _landingContent(),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  left: 8,
                  child: IconButton(
                    tooltip: 'Back',
                    onPressed: () => _showForm
                        ? setState(() => _showForm = false)
                        : context.go(AppRoutes.initial),
                    icon: const Icon(CupertinoIcons.chevron_left),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _landingContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          widget.role == AccountRole.admin
              ? 'Property24\nSupport'
              : 'One account.\nMany possibilities.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 30,
            height: 1.16,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.9,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          widget.role == AccountRole.admin
              ? 'Sign in to the private support workspace.'
              : 'Explore properties, stays, venues, services and jobs—or share what you offer.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 14,
            height: 1.5,
            letterSpacing: 0.05,
          ),
        ),
        const SizedBox(height: 24),
        _authChoice(),
        if (widget.role != AccountRole.admin) ...[
          const SizedBox(height: 18),
          Center(
            child: Text(
              'OR CONTINUE WITH',
              style: TextStyle(
                color: AppTheme.textMuted,
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
              ),
            ),
          ),
          const SizedBox(height: 14),
          _socialButtons(),
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
        ],
      ],
    );
  }

  Widget _authChoice() {
    if (widget.role == AccountRole.admin) {
      return InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () => setState(() {
          _showForm = true;
          _registering = false;
        }),
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.bgCard.withAlpha(190),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppTheme.border),
          ),
          child: const Text(
            'Support admin login',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      );
    }
    return Container(
      height: 44,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: AppTheme.bgCard.withAlpha(190),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Expanded(child: _choiceButton('Login', false)),
          Expanded(child: _choiceButton('Signup', true)),
        ],
      ),
    );
  }

  Widget _choiceButton(String label, bool registering) {
    final selected = _registering == registering;
    return GestureDetector(
      onTap: () => setState(() {
        _registering = registering;
        _showForm = true;
        _error = null;
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppTheme.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : AppTheme.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _socialButtons() {
    if (kIsWeb) {
      return GoogleWebSignInButton(onCredential: _googleAuthWithToken);
    }
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton.icon(
        onPressed: _submitting ? null : _googleAuth,
        icon: const _GoogleMark(),
        label: const Text('Continue with Google'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppTheme.textPrimary,
          side: BorderSide(color: AppTheme.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }

  Future<void> _googleAuthWithToken(String idToken) async {
    await _completeGoogleAuth(
      () => context.read<Property24State>().signInWithGoogleToken(
        idToken,
        _registering && widget.role != AccountRole.admin ? widget.role : null,
        marketplaceCapabilities: _propertyListingCapability,
      ),
    );
  }

  Future<void> _googleAuth() async {
    await _completeGoogleAuth(
      () => context.read<Property24State>().signInWithGoogle(
        _registering && widget.role != AccountRole.admin ? widget.role : null,
        marketplaceCapabilities: _propertyListingCapability,
      ),
    );
  }

  Future<void> _completeGoogleAuth(Future<void> Function() authenticate) async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await authenticate();
      if (mounted) context.go(AppRoutes.homeScreen);
    } catch (exception) {
      if (mounted) {
        final message = exception is ApiException
            ? exception.message
            : userFacingError(exception);
        setState(() {
          if (message.toLowerCase().contains('choose an account type')) {
            _registering = true;
            _showForm = true;
            _error = 'Choose Sign up to create your marketplace account.';
          } else {
            _error = message;
          }
        });
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Widget _formContent() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Text(
              _registering ? 'Create your account' : 'Welcome back',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 26,
                height: 1.18,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.6,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              _registering
                  ? 'One account to explore the marketplace and get started with what you need.'
                  : 'Sign in to continue where you left off.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 22),
          if (_registering) ...[
            _field(
              _name,
              'Full name',
              CupertinoIcons.person,
              (value) => value!.trim().isEmpty ? 'Enter your full name' : null,
            ),
            const SizedBox(height: 10),
          ],
          if (!_registering && widget.role != AccountRole.admin) ...[
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _submitting
                    ? null
                    : () => setState(() {
                        _phoneLogin = !_phoneLogin;
                        _phoneChallengeId = null;
                        _phoneCode.clear();
                        _error = null;
                      }),
                child: Text(
                  _phoneLogin ? 'Use email and password' : 'Sign in with phone',
                ),
              ),
            ),
          ],
          if (_phoneLogin && !_registering) ...[
            if (_phoneChallengeId == null) ...[
              Row(
                children: [
                  SizedBox(
                    width: 150,
                    child: DropdownButtonFormField<String>(
                      initialValue: _phoneCountry,
                      decoration: const InputDecoration(labelText: 'Country'),
                      items: const [
                        DropdownMenuItem(value: 'ZW', child: Text('🇿🇼 +263')),
                        DropdownMenuItem(value: 'ZA', child: Text('🇿🇦 +27')),
                        DropdownMenuItem(value: 'BW', child: Text('🇧🇼 +267')),
                        DropdownMenuItem(value: 'MZ', child: Text('🇲🇿 +258')),
                        DropdownMenuItem(value: 'ZM', child: Text('🇿🇲 +260')),
                        DropdownMenuItem(value: 'MW', child: Text('🇲🇼 +265')),
                        DropdownMenuItem(value: 'NA', child: Text('🇳🇦 +264')),
                        DropdownMenuItem(value: 'SZ', child: Text('🇸🇿 +268')),
                        DropdownMenuItem(value: 'LS', child: Text('🇱🇸 +266')),
                        DropdownMenuItem(value: 'GB', child: Text('🇬🇧 +44')),
                        DropdownMenuItem(value: 'US', child: Text('🇺🇸 +1')),
                      ],
                      onChanged: (value) =>
                          setState(() => _phoneCountry = value ?? 'ZW'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _phone,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Phone number',
                        hintText: '077 123 4567',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'By continuing, you agree to receive an SMS verification code for sign-in. Message and data rates may apply.',
                style: TextStyle(fontSize: 11),
              ),
            ] else ...[
              Text(
                'Enter the code sent to $_maskedDestination',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneCode,
                keyboardType: TextInputType.number,
                autofillHints: const [AutofillHints.oneTimeCode],
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                textAlign: TextAlign.center,
                decoration: const InputDecoration(
                  labelText: 'Verification code',
                ),
              ),
              TextButton(
                onPressed: _changePhoneNumber,
                child: const Text('Change number'),
              ),
              TextButton(
                onPressed: _resendSeconds > 0 || _submitting
                    ? null
                    : _resendPhoneCode,
                child: Text(
                  _resendSeconds > 0
                      ? 'Resend code in ${_resendSeconds}s'
                      : 'Resend code',
                ),
              ),
            ],
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _submitting ? null : _submit,
                child: Text(
                  _phoneChallengeId == null
                      ? 'Send verification code'
                      : 'Verify and sign in',
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Semantics(
                liveRegion: true,
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ],
          ],
          if (!_phoneLogin || _registering) ...[
            _field(_email, 'Email address', CupertinoIcons.at, (value) {
              final email = value?.trim() ?? '';
              return email.contains('@') && email.contains('.')
                  ? null
                  : 'Enter a valid email address';
            }, focusNode: _emailFocusNode),
            const SizedBox(height: 10),
            TextFormField(
              controller: _password,
              focusNode: _passwordFocusNode,
              onTap: () =>
                  FocusScope.of(context).requestFocus(_passwordFocusNode),
              obscureText: _obscurePassword,
              validator: (value) {
                final password = value ?? '';
                if (password.isEmpty) return 'Enter your password';
                if (_registering && password.length < 15) {
                  return 'Password must be at least 15 characters';
                }
                return null;
              },
              decoration: InputDecoration(
                hintText: 'Password',
                prefixIcon: const Icon(CupertinoIcons.lock, size: 18),
                suffixIcon: IconButton(
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                  icon: Icon(
                    _obscurePassword
                        ? CupertinoIcons.eye
                        : CupertinoIcons.eye_slash,
                    size: 18,
                  ),
                ),
              ),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontSize: 12,
              ),
            ),
          ],
          if (_registrationChallengeId != null) ...[
            const SizedBox(height: 10),
            TextFormField(
              controller: _emailCode,
              keyboardType: TextInputType.number,
              maxLength: 6,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: (value) => RegExp(r'^\d{6}$').hasMatch(value ?? '')
                  ? null
                  : 'Enter the 6-digit email code',
              decoration: const InputDecoration(
                hintText: 'Email verification code',
                prefixIcon: Icon(CupertinoIcons.mail, size: 18),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _submitting || _resendSeconds > 0
                    ? null
                    : _resendRegistrationEmail,
                child: Text(
                  _resendSeconds == 0
                      ? 'Resend code'
                      : 'Resend in ${_resendSeconds}s',
                ),
              ),
            ),
          ],
          const SizedBox(height: 14),
          if (widget.role != AccountRole.admin) ...[
            if (kIsWeb)
              GoogleWebSignInButton(onCredential: _googleAuthWithToken)
            else
              SizedBox(
                width: double.infinity,
                height: 44,
                child: OutlinedButton.icon(
                  onPressed: _submitting ? null : _googleAuth,
                  icon: const _GoogleMark(size: 20),
                  label: Text(
                    _registering
                        ? 'Create with Google'
                        : 'Continue with Google',
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.textPrimary,
                    side: BorderSide(color: AppTheme.border),
                    backgroundColor: AppTheme.bgCard.withAlpha(210),
                  ),
                ),
              ),
            const SizedBox(height: 10),
            Center(
              child: Text(
                'or continue with your account details',
                style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
              ),
            ),
            const SizedBox(height: 14),
          ],
          SizedBox(
            width: double.infinity,
            height: 44,
            child: FilledButton(
              onPressed: _submitting ? null : _submit,
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.accent,
                foregroundColor: Colors.white,
              ),
              child: _submitting
                  ? const CupertinoActivityIndicator(color: Colors.white)
                  : Text(
                      _registrationChallengeId != null
                          ? 'Verify email'
                          : _registering
                          ? 'Signup'
                          : 'Login',
                    ),
            ),
          ),
          if (widget.role != AccountRole.admin) ...[
            const SizedBox(height: 12),
            Center(
              child: TextButton(
                onPressed: () => setState(() {
                  _registering = !_registering;
                  _error = null;
                }),
                child: Text(
                  _registering
                      ? 'Already have an account? Login'
                      : 'New here? Signup',
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String hint,
    IconData icon,
    String? Function(String?) validator, {
    FocusNode? focusNode,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      focusNode: focusNode,
      onTap: focusNode == null
          ? null
          : () => FocusScope.of(context).requestFocus(focusNode),
      keyboardType: hint == 'Email address'
          ? TextInputType.emailAddress
          : TextInputType.text,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, size: 18),
      ),
    );
  }

  void _startResendCooldown([int seconds = 60]) {
    _resendTimer?.cancel();
    if (!mounted) return;
    setState(() => _resendSeconds = seconds);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendSeconds <= 1) {
        timer.cancel();
        setState(() => _resendSeconds = 0);
      } else {
        setState(() => _resendSeconds -= 1);
      }
    });
  }

  Future<void> _submit() async {
    if (_phoneLogin && !_registering) {
      setState(() {
        _submitting = true;
        _error = null;
      });
      try {
        final state = context.read<Property24State>();
        if (_phoneChallengeId == null) {
          final response = await state.sendPhoneLoginCode(
            phone: _phone.text.trim(),
            country: _phoneCountry,
          );
          if (!mounted) return;
          setState(() {
            _phoneChallengeId = '${response['challenge_id']}';
            _maskedDestination = '${response['destination']}';
          });
          _startResendCooldown(
            (response['resend_after'] as num?)?.toInt() ?? 30,
          );
        } else {
          await state.verifyPhoneLoginCode(
            challengeId: _phoneChallengeId!,
            code: _phoneCode.text.trim(),
          );
          if (mounted) context.go(AppRoutes.homeScreen);
        }
      } catch (exception) {
        if (mounted) setState(() => _error = userFacingError(exception));
      } finally {
        if (mounted) setState(() => _submitting = false);
      }
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    if (widget.role == AccountRole.admin && _registering) {
      setState(
        () => _error = 'Support accounts are provisioned on the server.',
      );
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    final state = context.read<Property24State>();
    try {
      if (_registering) {
        if (_registrationChallengeId != null) {
          await state.verifyRegistrationEmail(
            _registrationChallengeId!,
            _emailCode.text.trim(),
          );
          if (!mounted) return;
          context.go(AppRoutes.homeScreen);
          return;
        }
        _registrationChallengeId = await state.register(
          role: widget.role,
          name: _name.text.trim(),
          email: _email.text.trim(),
          password: _password.text,
          marketplaceCapabilities: _propertyListingCapability,
        );
        if (!mounted) return;
        setState(() => _showForm = true);
        _startResendCooldown();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Check your email for the verification code.'),
          ),
        );
      } else {
        await state.signIn(_email.text.trim(), _password.text);
        if (mounted) context.go(AppRoutes.homeScreen);
      }
    } catch (exception) {
      if (mounted) {
        setState(() {
          _error = exception is ApiException
              ? exception.message
              : userFacingError(exception);
        });
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _resendPhoneCode() async {
    final challengeId = _phoneChallengeId;
    if (challengeId == null) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final response = await context
          .read<Property24State>()
          .resendPhoneLoginCode(challengeId);
      if (!mounted) return;
      _startResendCooldown((response['resend_after'] as num?)?.toInt() ?? 30);
    } catch (exception) {
      if (mounted) setState(() => _error = userFacingError(exception));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _changePhoneNumber() async {
    final challengeId = _phoneChallengeId;
    if (challengeId != null) {
      try {
        await context.read<Property24State>().cancelPhoneLoginChallenge(
          challengeId,
        );
      } catch (_) {
        // The server also invalidates the challenge on the next send attempt.
      }
    }
    if (!mounted) return;
    _resendTimer?.cancel();
    setState(() {
      _phoneChallengeId = null;
      _resendSeconds = 0;
      _phoneCode.clear();
      _error = null;
    });
  }

  Future<void> _resendRegistrationEmail() async {
    final challengeId = _registrationChallengeId;
    if (challengeId == null) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final newChallengeId = await context
          .read<Property24State>()
          .resendRegistrationEmail(challengeId);
      if (!mounted) return;
      setState(() {
        _registrationChallengeId = newChallengeId;
        _emailCode.clear();
      });
      _startResendCooldown();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A new verification code was sent.')),
      );
    } catch (exception) {
      if (exception is ApiException && exception.statusCode == 429) {
        _startResendCooldown();
      }
      if (mounted) setState(() => _error = userFacingError(exception));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}

class _GoogleMark extends StatelessWidget {
  const _GoogleMark({this.size = 22});

  final double size;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => const SweepGradient(
        colors: [
          Color(0xff4285f4),
          Color(0xff34a853),
          Color(0xfffbbc05),
          Color(0xffea4335),
          Color(0xff4285f4),
        ],
      ).createShader(bounds),
      child: Text(
        'G',
        style: TextStyle(
          color: Colors.white,
          fontSize: size,
          fontWeight: FontWeight.w700,
          height: 1,
        ),
      ),
    );
  }
}
