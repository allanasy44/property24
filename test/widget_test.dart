import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:property24_zimbabwe/main.dart';

void main() {
  testWidgets('Property 24 app boots into the animated cover', (tester) async {
    await tester.pumpWidget(const MyApp(bootState: false));
    await tester.pump();

    expect(find.byType(PageView), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);
  });
}
