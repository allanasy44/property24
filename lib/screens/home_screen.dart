import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/rental_models.dart';
import '../routes/app_routes.dart';
import '../services/property24_api.dart';
import '../state/property24_state.dart';
import '../theme/app_theme.dart';
import '../widgets/property_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<Property24State>();
    final name = state.user?.name.trim().split(RegExp(r'\s+')).first ?? '';
    final properties = state.snapshot.properties
        .where(
          (property) =>
              property.owner?.id != state.user?.id &&
              property.agent?.id != state.user?.id,
        )
        .take(4)
        .toList();

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: state.refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 112),
            children: [
              Text(
                '${greetingForTime()}${name.isEmpty ? '' : ', $name'} 👋',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 18),
              _HomeSearch(
                controller: _searchController,
                onSubmitted: (query) =>
                    _openExplore(context, 'properties', query: query),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  for (final action in const [
                    _HomeAction(
                      label: 'Property',
                      icon: CupertinoIcons.house_fill,
                      market: 'properties',
                    ),
                    _HomeAction(
                      label: 'Services',
                      icon: CupertinoIcons.wrench_fill,
                      market: 'services',
                    ),
                    _HomeAction(
                      label: 'Jobs',
                      icon: CupertinoIcons.briefcase_fill,
                      market: 'jobs',
                    ),
                  ])
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: _ActionTile(
                          action: action,
                          onTap: () => _openExplore(context, action.market),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Recommended for you',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => _openExplore(context, 'properties'),
                    child: const Text('See all'),
                  ),
                ],
              ),
              if (state.loading && properties.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(
                    child: CircularProgressIndicator(color: AppTheme.accent),
                  ),
                )
              else if (properties.isEmpty)
                _EmptyRecommendations(
                  onExplore: () => _openExplore(context, 'properties'),
                )
              else
                for (final property in properties)
                  PropertyCard(
                    property: property,
                    saved: state.savedPropertyIds.contains(property.id),
                    onTap: () => context.pushNamed(
                      AppRoutes.propertyDetailName,
                      extra: property,
                    ),
                    onSave: () async {
                      try {
                        await context.read<Property24State>().toggleSaved(
                              property,
                            );
                      } catch (exception) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(userFacingError(exception)),
                            ),
                          );
                        }
                      }
                    },
                  ),
            ],
          ),
        ),
      ),
    );
  }

  void _openExplore(
    BuildContext context,
    String market, {
    String? query,
  }) {
    context.go(
      Uri(
        path: AppRoutes.exploreScreen,
        queryParameters: {
          'market': market,
          if (query?.trim().isNotEmpty == true) 'q': query!.trim(),
        },
      ).toString(),
    );
  }
}

class _HomeSearch extends StatelessWidget {
  const _HomeSearch({
    required this.controller,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.bgSurface,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 54,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.border),
        ),
        child: TextField(
          controller: controller,
          onSubmitted: onSubmitted,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: 'What are you looking for?',
            hintStyle: TextStyle(color: AppTheme.textMuted, fontSize: 13),
            prefixIcon: Icon(
              CupertinoIcons.search,
              color: AppTheme.textMuted,
            ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
      ),
    );
  }
}

class _HomeAction {
  const _HomeAction({
    required this.label,
    required this.icon,
    required this.market,
  });

  final String label;
  final IconData icon;
  final String market;
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({required this.action, required this.onTap});

  final _HomeAction action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.bgCard,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 94,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.border),
          ),
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(action.icon, size: 25, color: AppTheme.accent),
              const SizedBox(height: 8),
              Text(
                action.label,
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyRecommendations extends StatelessWidget {
  const _EmptyRecommendations({required this.onExplore});

  final VoidCallback onExplore;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: [
          Icon(CupertinoIcons.house, color: AppTheme.textMuted, size: 30),
          const SizedBox(height: 8),
          Text(
            'New listings will show up here',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Explore available homes, stays, and venues.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 8),
          TextButton(onPressed: onExplore, child: const Text('Explore listings')),
        ],
      ),
    );
  }
}
