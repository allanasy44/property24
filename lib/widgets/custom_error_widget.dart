import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';

import '../routes/app_routes.dart';
import '../theme/app_theme.dart';

class CustomErrorWidget extends StatelessWidget {
  const CustomErrorWidget({
    this.errorDetails,
    this.errorMessage,
    super.key,
  });

  final FlutterErrorDetails? errorDetails;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: AppTheme.accent.withAlpha(28),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.accent.withAlpha(80)),
                  ),
                  child: const Icon(
                    CupertinoIcons.exclamationmark_circle,
                    color: AppTheme.accent,
                    size: 30,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Something went wrong',
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  errorMessage ??
                      'We encountered an unexpected error while processing your request.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () {
                    if (context.canPop()) {
                      context.pop();
                    } else {
                      context.goNamed(AppRoutes.homeName);
                    }
                  },
                  icon: const Icon(CupertinoIcons.arrow_left, size: 18),
                  label: const Text('Back'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
