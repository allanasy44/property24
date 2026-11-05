import 'package:flutter/material.dart';

class GoogleWebSignInButton extends StatelessWidget {
  const GoogleWebSignInButton({required this.onCredential, super.key});

  final ValueChanged<String> onCredential;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
