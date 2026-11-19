import 'package:flutter/material.dart';

class GoogleWebSignInButton extends StatelessWidget {
  const GoogleWebSignInButton({
    required this.onCredential,
    this.isRegistration = false,
    super.key,
  });

  final ValueChanged<String> onCredential;
  final bool isRegistration;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
