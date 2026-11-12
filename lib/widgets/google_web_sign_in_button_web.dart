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

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Text(_error!);
    }
    if (!_initialized) {
      return const SizedBox(
        height: 48,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return SizedBox(
      height: 48,
      width: double.infinity,
      child: google_web.renderButton(),
    );
  }
}
