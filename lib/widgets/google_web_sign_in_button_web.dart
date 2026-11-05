import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';
import 'package:google_sign_in_web/web_only.dart' as google_web;

import '../services/property24_api.dart';

class GoogleWebSignInButton extends StatefulWidget {
  const GoogleWebSignInButton({required this.onCredential, super.key});

  final ValueChanged<String> onCredential;

  @override
  State<GoogleWebSignInButton> createState() => _GoogleWebSignInButtonState();
}

class _GoogleWebSignInButtonState extends State<GoogleWebSignInButton> {
  GoogleSignIn? _signIn;
  StreamSubscription<GoogleSignInUserData?>? _subscription;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      final clientId = await Property24Api().googleWebClientId();
      _signIn = GoogleSignIn(clientId: clientId);
      _subscription = GoogleSignInPlatform.instance.userDataEvents?.listen((
        data,
      ) {
        final idToken = data?.idToken;
        if (idToken != null && idToken.isNotEmpty) {
          widget.onCredential(idToken);
        }
      });
      if (mounted) setState(() {});
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
    if (!mounted || !_isInitialized) {
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

  bool get _isInitialized => _signIn != null && _subscription != null;
}
