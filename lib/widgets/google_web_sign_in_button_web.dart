import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:google_sign_in_web/web_only.dart' as google_web;

import '../services/property24_api.dart';

class GoogleWebSignInButton extends StatefulWidget {
  const GoogleWebSignInButton({required this.onCredential, super.key});

  final ValueChanged<String> onCredential;

  @override
  State<GoogleWebSignInButton> createState() => _GoogleWebSignInButtonState();
}

class _GoogleWebSignInButtonState extends State<GoogleWebSignInButton> {
  StreamSubscription<GoogleSignInAuthenticationEvent>? _subscription;
  String? _error;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      await _subscription?.cancel();
      _subscription = null;
      await Property24Api().initializeGoogleSignIn();
      _subscription = GoogleSignIn.instance.authenticationEvents.listen(
        (event) {
          if (event case GoogleSignInAuthenticationEventSignIn(:final user)) {
            final idToken = user.authentication.idToken;
            if (idToken != null && idToken.isNotEmpty) {
              widget.onCredential(idToken);
            }
          }
        },
        onError: (Object exception) {
          if (mounted) {
            setState(() => _error = userFacingError(exception));
          }
        },
      );
      if (mounted) setState(() => _initialized = true);
    } catch (exception) {
      if (mounted) setState(() => _error = userFacingError(exception));
    }
  }

  void _retryInitialization() {
    setState(() {
      _error = null;
      _initialized = false;
    });
    _initialize();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_error!, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: _retryInitialization,
              icon: const Text(
                'G',
                style: TextStyle(
                  color: Color(0xff4285f4),
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              label: const Text('Sign in with Google'),
            ),
          ),
        ],
      );
    }
    if (!_initialized) {
      return SizedBox(
        height: 48,
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: null,
          icon: Text(
            'G',
            style: TextStyle(
              color: Color(0xff4285f4),
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          label: Text('Sign in with Google'),
        ),
      );
    }
    return SizedBox(
      height: 48,
      width: double.infinity,
      child: google_web.renderButton(),
    );
  }
}
