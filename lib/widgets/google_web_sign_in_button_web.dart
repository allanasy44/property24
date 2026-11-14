import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:google_sign_in_web/web_only.dart' as google_web;

import '../services/property24_api.dart';

class GoogleWebSignInButton extends StatefulWidget {
  const GoogleWebSignInButton({
    required this.onCredential,
    this.isRegistration = false,
    super.key,
  });

  final ValueChanged<String> onCredential;
  final bool isRegistration;

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

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Text(_error!, textAlign: TextAlign.center);
    }
    if (!_initialized) {
      return const SizedBox(
        height: 48,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : 320.0;
        final buttonWidth = availableWidth / 2;
        return Center(
          child: SizedBox(
            height: 48,
            width: buttonWidth,
            child: google_web.renderButton(
              configuration: google_web.GSIButtonConfiguration(
                theme: google_web.GSIButtonTheme.outline,
                size: google_web.GSIButtonSize.large,
                shape: google_web.GSIButtonShape.rectangular,
                logoAlignment: google_web.GSIButtonLogoAlignment.left,
                text: widget.isRegistration
                    ? google_web.GSIButtonText.signupWith
                    : google_web.GSIButtonText.continueWith,
                minimumWidth: buttonWidth,
              ),
            ),
          ),
        );
      },
    );
  }
}
