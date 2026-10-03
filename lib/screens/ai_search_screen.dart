import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import 'package:provider/provider.dart';

import '../models/rental_models.dart';
import '../state/property24_state.dart';
import '../services/property24_api.dart';
import '../widgets/property_card.dart';
import 'property_detail_screen.dart';
import '../theme/app_theme.dart';

class AiSearchScreen extends StatefulWidget {
  const AiSearchScreen({
    this.initialQuery = '',
    this.searchScope = 'discover',
    super.key,
  });

  final String initialQuery;
  final String searchScope;

  @override
  State<AiSearchScreen> createState() => _AiSearchScreenState();
}

class _AiSearchScreenState extends State<AiSearchScreen> {
  static const _accent = AppTheme.accent;
  AiSearchResponse? _response;
  bool _searching = false;
  String? _error;

  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialQuery);
    _focusNode = FocusNode();
    _hasText = widget.initialQuery.trim().isNotEmpty;
    _controller.addListener(_handleTextChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.removeListener(_handleTextChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleTextChanged() {
    final hasText = _controller.text.trim().isNotEmpty;
    if (hasText != _hasText) setState(() => _hasText = hasText);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: AppTheme.bg,
        systemNavigationBarColor: AppTheme.bg,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        systemNavigationBarIconBrightness:
            isDark ? Brightness.light : Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: AppTheme.bg,
        resizeToAvoidBottomInset: true,
        body: SafeArea(
          top: true,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          height: 44,
                          width: 44,
                          decoration: BoxDecoration(
                            color: AppTheme.bgCard,
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            tooltip: 'Back',
                            onPressed: () => Navigator.pop(context),
                            padding: EdgeInsets.zero,
                            icon: const Icon(CupertinoIcons.chevron_left),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'AI property matching',
                                style: TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                'Describe the home you need',
                                style: TextStyle(
                                  color: AppTheme.textMuted,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    _PromptBox(
                      controller: _controller,
                      focusNode: _focusNode,
                      hasText: _hasText,
                      onClear: _controller.clear,
                      onSubmit: _submit,
                      searching: _searching,
                    ),
                    const SizedBox(height: 20),
                    Expanded(
                      child: _SearchResults(
                        response: _response,
                        searching: _searching,
                        error: _error,
                        onSaveSearch: _response == null ? null : _saveSearch,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _submit([String? value]) {
    final query = (value ?? _controller.text).trim();
    if (query.isEmpty) return;
    _runSearch(query);
  }

  Future<void> _runSearch(String query) async {
    setState(() {
      _searching = true;
      _error = null;
    });
    try {
      final response = await context.read<Property24State>().searchWithAi(
            query,
            scope: widget.searchScope,
          );
      if (!mounted) return;
      setState(() => _response = response);
    } catch (exception) {
      if (!mounted) return;
      setState(() => _error = userFacingError(exception));
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _saveSearch() async {
    final query = _response?.query.trim() ?? '';
    if (query.isEmpty) return;
    try {
      await context.read<Property24State>().saveSearch(query);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Search saved. New live matches will alert you.')),
        );
      }
    } catch (exception) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(userFacingError(exception))),
        );
      }
    }
  }
}

class _SearchResults extends StatelessWidget {
  const _SearchResults({
    required this.response,
    required this.searching,
    required this.error,
    required this.onSaveSearch,
  });

  final AiSearchResponse? response;
  final bool searching;
  final String? error;
  final VoidCallback? onSaveSearch;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (searching) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(strokeWidth: 2.5),
            const SizedBox(height: 14),
            Text(
              'Finding the closest live listings',
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      );
    }
    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                CupertinoIcons.exclamationmark_circle,
                color: theme.colorScheme.error,
                size: 30,
              ),
              const SizedBox(height: 10),
              Text(
                error!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      );
    }
    final result = response;
    if (result == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                CupertinoIcons.house,
                color: theme.colorScheme.primary,
                size: 34,
              ),
              const SizedBox(height: 12),
              Text(
                'Tell us what would make the home feel right',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Try bedrooms, budget, location, water, parking, or distance to town.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      );
    }
    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Text(
                'Matches',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Text(
              '${result.results.length} ${result.results.length == 1 ? 'listing' : 'listings'}',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              tooltip: 'Save search alerts',
              onPressed: onSaveSearch,
              icon: const Icon(CupertinoIcons.bell),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _IntentSummary(intent: result.intent),
        const SizedBox(height: 10),
        Text(
          result.explanation,
          style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
        ),
        const SizedBox(height: 16),
        for (final item in result.results)
          _AiMatchResult(
            item: item,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => PropertyDetailScreen(
                  property: item.property,
                ),
              ),
            ),
          ),
        if (result.results.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 28),
            child: Center(
              child: Text(
                'No matching live listings yet.',
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ),
      ],
    );
  }
}

class _AiMatchResult extends StatelessWidget {
  const _AiMatchResult({required this.item, required this.onTap});

  final AiSearchCandidate item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PropertyCard(
          property: item.property,
          trailing: _MatchBadge(score: item.score),
          onTap: onTap,
        ),
        if (item.reasons.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Why this match',
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                for (final reason in item.reasons)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          reason.contains('above') ||
                                  reason.contains('not confirmed')
                              ? CupertinoIcons.exclamationmark_circle
                              : CupertinoIcons.checkmark_circle_fill,
                          color: reason.contains('above') ||
                                  reason.contains('not confirmed')
                              ? theme.colorScheme.tertiary
                              : theme.colorScheme.primary,
                          size: 16,
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            reason,
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _IntentSummary extends StatelessWidget {
  const _IntentSummary({required this.intent});

  final Map<String, dynamic> intent;

  @override
  Widget build(BuildContext context) {
    final values = <String>[
      if (intent['bedrooms_min'] != null) '${intent['bedrooms_min']}+ beds',
      if ('${intent['budget_max'] ?? ''}'.isNotEmpty)
        'up to \$${intent['budget_max']}',
      if ('${intent['city'] ?? ''}'.isNotEmpty) '${intent['city']}',
      if (intent['water_reliability'] == true) 'reliable water',
      if (intent['parking'] == true) 'parking',
      if (intent['quiet_area'] == true) 'quiet area',
      if (intent['distance_to_town'] == 'short') 'near town',
    ];
    if (values.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final value in values)
          DecoratedBox(
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              child: Text(
                value,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _MatchBadge extends StatelessWidget {
  const _MatchBadge({required this.score});

  final int score;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 76),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '$score% match',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onPrimaryContainer,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
      ),
    );
  }
}

class _PromptBox extends StatelessWidget {
  const _PromptBox({
    required this.controller,
    required this.focusNode,
    required this.hasText,
    required this.onClear,
    required this.onSubmit,
    required this.searching,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool hasText;
  final VoidCallback onClear;
  final ValueChanged<String?> onSubmit;
  final bool searching;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 12, 10),
      decoration: BoxDecoration(
        color: AppTheme.bgSurface,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: controller,
            focusNode: focusNode,
            minLines: 1,
            maxLines: 4,
            textInputAction: TextInputAction.search,
            cursorColor: _AiSearchScreenState._accent,
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 14,
              height: 1.4,
            ),
            decoration: InputDecoration(
              isDense: true,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              disabledBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              focusedErrorBorder: InputBorder.none,
              contentPadding: EdgeInsets.zero,
              hintText: 'Describe your ideal home...',
              hintStyle: TextStyle(
                color: AppTheme.textMuted,
                fontSize: 14,
                height: 1.4,
              ),
            ),
            onSubmitted: onSubmit,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Spacer(),
              if (hasText) ...[
                IconButton(
                  tooltip: 'Clear search',
                  onPressed: onClear,
                  style: IconButton.styleFrom(
                    backgroundColor: AppTheme.bgSurface,
                    foregroundColor: AppTheme.textMuted,
                    fixedSize: const Size.square(38),
                    minimumSize: const Size.square(38),
                  ),
                  icon: const Icon(CupertinoIcons.xmark, size: 18),
                ),
                const SizedBox(width: 8),
              ],
              IconButton(
                tooltip: 'Search',
                onPressed: hasText && !searching ? () => onSubmit(null) : null,
                style: IconButton.styleFrom(
                  backgroundColor: AppTheme.accent,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppTheme.border,
                  disabledForegroundColor: AppTheme.textMuted,
                  fixedSize: const Size.square(42),
                  minimumSize: const Size.square(42),
                ),
                icon: searching
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(CupertinoIcons.search, size: 19),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
