import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/rental_models.dart';
import '../routes/app_routes.dart';
import '../services/property24_api.dart';
import '../state/property24_state.dart';
import '../theme/app_theme.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({required this.role, super.key});

  final AccountRole role;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _emailCode = TextEditingController();
  bool _registering = false;
  bool _showForm = false;
  bool _obscurePassword = true;
  bool _submitting = false;
  String? _registrationChallengeId;
  String? _error;

  static const _heroImage =
      'https://images.pexels.com/photos/323780/pexels-photo-323780.jpeg?auto=compress&cs=tinysrgb&w=1200';

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _emailCode.dispose();
    super.dispose();
  }

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
                _background(),
                SingleChildScrollView(
                  padding: EdgeInsets.only(
                    top: 18,
                    left: 18,
                    right: 18,
                    bottom: MediaQuery.viewInsetsOf(context).bottom + 24,
                  ),
                  child: ConstrainedBox(
                    constraints:
                        BoxConstraints(minHeight: constraints.maxHeight - 42),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        const SizedBox(height: 250),
                        if (_showForm) _formContent() else _landingContent(),
                      ],
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

  Widget _background() {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: NetworkImage(_heroImage),
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
          ),
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: const [0.42, 0.64, 0.82, 1],
              colors: [
                Colors.transparent,
                AppTheme.bgCard.withAlpha(120),
                AppTheme.bgCard.withAlpha(238),
                AppTheme.bgCard,
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _landingContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Connecting You\nwith the\nPerfect Property',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 32,
            height: 1.12,
            fontWeight: FontWeight.w500,
            letterSpacing: -0.7,
          ),
        ),
        const SizedBox(height: 22),
        _authChoice(),
        const SizedBox(height: 14),
        const Center(
          child: Text(
            'Continue With Following',
            style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
          ),
        ),
        const SizedBox(height: 12),
        _socialButtons(),
      ],
    );
  }

  Widget _authChoice() {
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
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _socialButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _socialButton(
          const Icon(CupertinoIcons.person_fill),
          AppTheme.accent,
          onTap: _googleAuth,
        ),
      ],
    );
  }

  Widget _socialButton(Widget icon, Color color,
      {required VoidCallback onTap}) {
    return InkWell(
      onTap: _submitting ? null : onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          shape: BoxShape.circle,
          border: Border.all(color: AppTheme.border),
        ),
        child:
            IconTheme(data: IconThemeData(color: color, size: 18), child: icon),
      ),
    );
  }

  Future<void> _googleAuth() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await context.read<Property24State>().signInWithGoogle(widget.role);
      if (mounted) context.go(AppRoutes.homeScreen);
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

  Widget _formContent() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _registering ? 'Create your account' : 'Welcome back',
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 28,
              height: 1.1,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${widget.role.label} account',
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 16),
          if (_registering) ...[
            _field(
                _name,
                'Full name',
                CupertinoIcons.person,
                (value) =>
                    value!.trim().isEmpty ? 'Enter your full name' : null),
            const SizedBox(height: 10),
          ],
          _field(_email, 'Email address', CupertinoIcons.at, (value) {
            final email = value?.trim() ?? '';
            return email.contains('@') && email.contains('.')
                ? null
                : 'Enter a valid email address';
          }),
          const SizedBox(height: 10),
          TextFormField(
            controller: _password,
            obscureText: _obscurePassword,
            validator: (value) => (value?.length ?? 0) < 15
                ? 'Password must be at least 15 characters'
                : null,
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
                    size: 18),
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!,
                style: TextStyle(
                    color: Theme.of(context).colorScheme.error, fontSize: 12)),
          ],
          if (_registrationChallengeId != null) ...[
            const SizedBox(height: 10),
            TextFormField(
              controller: _emailCode,
              keyboardType: TextInputType.number,
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
                onPressed: _submitting ? null : _resendRegistrationEmail,
                child: const Text('Resend code'),
              ),
            ),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: OutlinedButton.icon(
              onPressed: _submitting ? null : _googleAuth,
              icon: const Icon(CupertinoIcons.person_fill, size: 18),
              label: Text(
                _registering ? 'Create with Google' : 'Continue with Google',
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.textPrimary,
                side: const BorderSide(color: AppTheme.border),
                backgroundColor: AppTheme.bgCard.withAlpha(210),
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Center(
            child: Text(
              'or use email and password',
              style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: FilledButton(
              onPressed: _submitting ? null : _submit,
              style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.accent,
                  foregroundColor: Colors.white),
              child: _submitting
                  ? const CupertinoActivityIndicator(color: Colors.white)
                  : Text(_registrationChallengeId != null
                      ? 'Verify email'
                      : _registering
                          ? 'Signup'
                          : 'Login'),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: TextButton(
              onPressed: () => setState(() {
                _registering = !_registering;
                _error = null;
              }),
              child: Text(_registering
                  ? 'Already have an account? Login'
                  : 'New here? Signup'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(TextEditingController controller, String hint, IconData icon,
      String? Function(String?) validator) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: hint == 'Email address'
          ? TextInputType.emailAddress
          : TextInputType.text,
      decoration:
          InputDecoration(hintText: hint, prefixIcon: Icon(icon, size: 18)),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    final state = context.read<Property24State>();
    try {
      if (_registering) {
        if (_registrationChallengeId != null) {
          await state.verifyRegistrationEmail(
              _registrationChallengeId!, _emailCode.text.trim());
          if (!mounted) return;
          context.go(AppRoutes.homeScreen);
          return;
        }
        _registrationChallengeId = await state.register(
          role: widget.role,
          name: _name.text.trim(),
          email: _email.text.trim(),
          password: _password.text,
        );
        if (!mounted) return;
        setState(() => _showForm = true);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Check your email for the verification code.')));
      } else {
        await state.signIn(_email.text.trim(), _password.text,
            role: widget.role);
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
      setState(() => _registrationChallengeId = newChallengeId);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A new verification code was sent.')),
      );
    } catch (exception) {
      if (mounted) setState(() => _error = userFacingError(exception));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}
