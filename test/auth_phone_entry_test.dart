import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:property24_zimbabwe/models/rental_models.dart';
import 'package:property24_zimbabwe/screens/auth_screen.dart';
import 'package:property24_zimbabwe/state/property24_state.dart';

void main() {
  testWidgets(
    'phone sign-in exposes country selection and consent before sending',
    (tester) async {
      final state = Property24State();
      final router = GoRouter(
        initialLocation: '/auth',
        routes: [
          GoRoute(
            path: '/auth',
            builder: (_, _) => const AuthScreen(role: AccountRole.tenant),
          ),
        ],
      );
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: state,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.tap(find.text('Login'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sign in with phone'));
      await tester.pumpAndSettle();

      expect(find.text('Send verification code'), findsOneWidget);
      expect(find.textContaining('+263'), findsOneWidget);
      expect(
        find.textContaining('agree to receive an SMS verification code'),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      state.dispose();
      router.dispose();
    },
  );
}
