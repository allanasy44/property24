import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:sizer/sizer.dart';

import 'routes/app_routes.dart';
import 'state/property24_state.dart';
import 'theme/app_theme.dart';
import 'widgets/custom_error_widget.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  var hasShownError = false;

  // CRITICAL: Custom error handling.
  ErrorWidget.builder = (FlutterErrorDetails details) {
    if (!hasShownError) {
      hasShownError = true;
      Future<void>.delayed(const Duration(seconds: 5), () {
        hasShownError = false;
      });
      return CustomErrorWidget(errorDetails: details);
    }
    return const SizedBox.shrink();
  };

  // CRITICAL: Device orientation lock.
  await Future.wait([
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]),
  ]);

  GoRouter.optionURLReflectsImperativeAPIs = true;
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({
    this.bootState = true,
    super.key,
  });

  final bool bootState;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) {
        final state = Property24State();
        if (bootState) state.boot();
        return state;
      },
      child: Sizer(
        builder: (context, orientation, screenType) {
          return Consumer<Property24State>(
            builder: (context, state, _) {
              return MaterialApp.router(
                title: 'Property 24',
                theme: AppTheme.lightTheme,
                darkTheme: AppTheme.darkTheme,
                themeMode: state.darkMode ? ThemeMode.dark : ThemeMode.light,
                builder: (context, child) {
                  return MediaQuery(
                    data: MediaQuery.of(
                      context,
                    ).copyWith(textScaler: TextScaler.linear(1.0)),
                    child: child ?? const SizedBox.shrink(),
                  );
                },
                debugShowCheckedModeBanner: false,
                routerConfig: appRouter,
              );
            },
          );
        },
      ),
    );
  }
}
