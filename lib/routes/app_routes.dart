import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/rental_models.dart';
import '../screens/activity_screen.dart';
import '../screens/calls_screen.dart';
import '../screens/discover_screen.dart';
import '../screens/inbox_screen.dart';
import '../screens/listings_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/property_detail_screen.dart';
import '../screens/splash_screen.dart';
import '../widgets/app_scaffold.dart';

class AppRoutes {
  const AppRoutes._();

  static const String initial = '/';
  static const String homeName = 'home';
  static const String callsName = 'calls';
  static const String chatName = 'chat';
  static const String listingsName = 'listings';
  static const String inboxName = 'inbox';
  static const String activityName = 'activity';
  static const String profileName = 'profile';
  static const String propertyDetailName = 'property-detail';

  static const String homeScreen = '/home';
  static const String callsScreen = '/calls';
  static const String chatScreen = '/chat';
  static const String listingsScreen = '/listings';
  static const String inboxScreen = '/inbox';
  static const String activityScreen = '/activity';
  static const String profileScreen = '/profile';
  static const String propertyDetailScreen = '/property-detail';
}

final GoRouter appRouter = GoRouter(
  initialLocation: AppRoutes.initial,
  routes: [
    GoRoute(
      path: AppRoutes.initial,
      pageBuilder: (context, state) => _fadePage(
        state,
        const SplashScreen(),
      ),
    ),
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          AppScaffold(navigationShell: navigationShell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.homeScreen,
              name: AppRoutes.homeName,
              pageBuilder: (context, state) => _fadePage(
                state,
                const DiscoverScreen(),
              ),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.callsScreen,
              name: AppRoutes.callsName,
              pageBuilder: (context, state) => _fadePage(
                state,
                const CallsScreen(),
              ),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.chatScreen,
              name: AppRoutes.chatName,
              pageBuilder: (context, state) => _fadePage(
                state,
                const InboxScreen(),
              ),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.profileScreen,
              name: AppRoutes.profileName,
              pageBuilder: (context, state) => _fadePage(
                state,
                const ProfileScreen(),
              ),
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      path: AppRoutes.listingsScreen,
      name: AppRoutes.listingsName,
      pageBuilder: (context, state) => _fadePage(
        state,
        const ListingsScreen(),
      ),
    ),
    GoRoute(
      path: AppRoutes.activityScreen,
      name: AppRoutes.activityName,
      pageBuilder: (context, state) => _fadePage(
        state,
        const ActivityScreen(),
      ),
    ),
    GoRoute(
      path: AppRoutes.propertyDetailScreen,
      name: AppRoutes.propertyDetailName,
      pageBuilder: (context, state) {
        final property = state.extra is PropertyListing
            ? state.extra! as PropertyListing
            : null;
        return CustomTransitionPage<void>(
          key: state.pageKey,
          child: property == null
              ? const DiscoverScreen()
              : PropertyDetailScreen(property: property),
          transitionDuration: const Duration(milliseconds: 320),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.05),
                end: Offset.zero,
              ).animate(
                CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeOutCubic,
                ),
              ),
              child: FadeTransition(opacity: animation, child: child),
            );
          },
        );
      },
    ),
  ],
);

CustomTransitionPage<void> _fadePage(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 250),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: child,
      );
    },
  );
}
