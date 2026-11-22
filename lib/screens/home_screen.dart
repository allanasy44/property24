import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/rental_models.dart';
import '../routes/app_routes.dart';
import '../services/property24_api.dart';
import '../state/property24_state.dart';
import '../theme/app_theme.dart';
import '../widgets/notification_button.dart';
import '../widgets/property_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<Property24State>();
    final name = state.user?.name.trim().split(RegExp(r'\s+')).first ?? '';
    final query = _query.trim().toLowerCase();
    final properties = state.snapshot.properties
        .where((property) {
          if (property.owner?.id == state.user?.id ||
              property.agent?.id == state.user?.id) {
            return false;
          }
          if (query.isEmpty) return true;
          final searchableText = [
            property.title,
            property.address,
            property.city,
            property.suburb,
            property.propertyType,
            property.description,
          ].join(' ').toLowerCase();
          return searchableText.contains(query);
        })
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
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          greetingForTime(),
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            letterSpacing: 0.2,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          name.isEmpty ? 'Welcome home' : name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 28,
                            height: 1.1,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.6,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  NotificationButton(state: state),
                ],
              ),
              const SizedBox(height: 18),
              _HomeSearch(
                controller: _searchController,
                onChanged: (value) => setState(() => _query = value),
                onSubmitted: (value) => setState(() => _query = value),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  for (var index = 0; index < _homeActions.length; index++)
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(
                          right: index == _homeActions.length - 1 ? 0 : 8,
                        ),
                        child: _ActionTile(
                          action: _homeActions[index],
                          onTap: () =>
                              _openExplore(context, _homeActions[index].market),
                        ),
                      ),
                    ),
                ],
              ),
              if (state.user != null && !state.canManageListings) ...[
                const SizedBox(height: 14),
                _VerifyIdentityCard(
                  onTap: () => context.go(AppRoutes.profileScreen),
                ),
              ],
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
                            SnackBar(content: Text(userFacingError(exception))),
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

  void _openExplore(BuildContext context, String market, {String? query}) {
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
    required this.onChanged,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
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
          onChanged: onChanged,
          onSubmitted: onSubmitted,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: 'What are you looking for?',
            hintStyle: TextStyle(color: AppTheme.textMuted, fontSize: 13),
            prefixIcon: Icon(CupertinoIcons.search, color: AppTheme.textMuted),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            disabledBorder: InputBorder.none,
            errorBorder: InputBorder.none,
            focusedErrorBorder: InputBorder.none,
            filled: false,
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

const _homeActions = [
  _HomeAction(
    label: 'Homes',
    icon: CupertinoIcons.building_2_fill,
    market: 'properties',
  ),
  _HomeAction(
    label: 'Stays',
    icon: CupertinoIcons.bed_double_fill,
    market: 'stays',
  ),
  _HomeAction(label: 'Venues', icon: CupertinoIcons.star, market: 'venues'),
  _HomeAction(
    label: 'Services',
    icon: CupertinoIcons.pencil,
    market: 'services',
  ),
  _HomeAction(label: 'Jobs', icon: CupertinoIcons.briefcase, market: 'jobs'),
];

class _VerifyIdentityCard extends StatelessWidget {
  const _VerifyIdentityCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.bgCard,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.border),
            boxShadow: [
              BoxShadow(
                color: const Color(0xff201044).withValues(alpha: 0.05),
                blurRadius: 18,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppTheme.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  CupertinoIcons.shield,
                  color: AppTheme.accent,
                  size: 25,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Verify your ID',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Required before you can list',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(CupertinoIcons.chevron_right, color: AppTheme.textPrimary),
            ],
          ),
        ),
      ),
    );
  }
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
          height: 88,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppTheme.border),
          ),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(action.icon, size: 24, color: AppTheme.accent),
              const SizedBox(height: 7),
              Text(
                action.label,
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 10,
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
          TextButton(
            onPressed: onExplore,
            child: const Text('Explore listings'),
          ),
        ],
      ),
    );
  }
}
