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
    super.key,
  });

  final String initialQuery;

  @override
  State<AiSearchScreen> createState() => _AiSearchScreenState();
}

class _AiSearchScreenState extends State<AiSearchScreen> {
  static Color get _bg => AppTheme.bg;
  static Color get _panel => AppTheme.bgCard;
  static Color get _panelBorder => AppTheme.borderMid;
  static const _accent = AppTheme.accent;
  AiSearchResponse? _response;
  bool _searching = false;
  String? _error;
  static Color get _text => AppTheme.textPrimary;
  static Color get _muted => AppTheme.textMuted;

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
        statusBarColor: _bg,
        systemNavigationBarColor: _bg,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        systemNavigationBarIconBrightness:
            isDark ? Brightness.light : Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: _bg,
        resizeToAvoidBottomInset: true,
        body: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [_panel, AppTheme.bg],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SearchHeader(onBack: () => Navigator.pop(context)),
                  const SizedBox(height: 18),
                  _PromptBox(
                    controller: _controller,
                    focusNode: _focusNode,
                    hasText: _hasText,
                    onClear: _controller.clear,
                    onSubmit: _submit,
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: _SearchResults(
                      response: _response,
                      searching: _searching,
                      error: _error,
                    ),
                  ),
                ],
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
      final response =
          await context.read<Property24State>().searchWithAi(query);
      if (!mounted) return;
      setState(() => _response = response);
    } catch (exception) {
      if (!mounted) return;
      setState(() => _error = userFacingError(exception));
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }
}

class _SearchResults extends StatelessWidget {
  const _SearchResults(
      {required this.response, required this.searching, required this.error});

  final AiSearchResponse? response;
  final bool searching;
  final String? error;

  @override
  Widget build(BuildContext context) {
    if (searching) return Center(child: CircularProgressIndicator());
    if (error != null)
      return Center(
          child: Text(error!, style: TextStyle(color: Colors.redAccent)));
    final result = response;
    if (result == null) {
      return Center(
          child: Text(
              'Describe the home you need and I will rank live listings for you.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textMuted, fontSize: 13)));
    }
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        Text(result.explanation,
            style: TextStyle(
                color: AppTheme.textSecondary, fontSize: 13, height: 1.4)),
        const SizedBox(height: 14),
        for (final item in result.results)
          PropertyCard(
            property: item.property,
            onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => PropertyDetailScreen(property: item.property))),
          ),
        if (result.results.isEmpty)
          const Padding(
              padding: EdgeInsets.only(top: 28),
              child: Center(child: Text('No matching live listings yet.'))),
      ],
    );
  }
}

class _SearchHeader extends StatelessWidget {
  const _SearchHeader({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              tooltip: 'Back',
              onPressed: onBack,
              style: IconButton.styleFrom(
                backgroundColor: AppTheme.bgCard,
                foregroundColor: AppTheme.textPrimary,
                fixedSize: const Size.square(36),
                minimumSize: const Size.square(36),
              ),
              icon: Icon(CupertinoIcons.chevron_left, size: 20),
            ),
          ),
          Text(
            'AI Search',
            style: TextStyle(
              color: _AiSearchScreenState._text,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
          ),
        ],
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
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool hasText;
  final VoidCallback onClear;
  final ValueChanged<String?> onSubmit;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 132,
      padding: const EdgeInsets.fromLTRB(14, 14, 12, 12),
      decoration: BoxDecoration(
        color: _AiSearchScreenState._panel,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _AiSearchScreenState._panelBorder),
        boxShadow: [
          BoxShadow(
            color: _AiSearchScreenState._accent.withOpacity(0.12),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 22,
                width: 22,
                margin: const EdgeInsets.only(top: 1),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: _AiSearchScreenState._accent),
                ),
                child: Center(
                  child: Icon(
                    CupertinoIcons.circle,
                    color: _AiSearchScreenState._accent,
                    size: 6,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  minLines: 1,
                  maxLines: 3,
                  textInputAction: TextInputAction.search,
                  cursorColor: _AiSearchScreenState._accent,
                  style: TextStyle(
                    color: _AiSearchScreenState._text,
                    fontSize: 14,
                    height: 1.4,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    hintText: '',
                    hintStyle: TextStyle(
                      color: _AiSearchScreenState._muted,
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  onSubmitted: onSubmit,
                ),
              ),
            ],
          ),
          const Spacer(),
          Row(
            children: [
              IconButton(
                tooltip: 'Voice search',
                onPressed: () {},
                style: IconButton.styleFrom(
                  backgroundColor: AppTheme.bgSurface,
                  foregroundColor: AppTheme.textPrimary,
                  fixedSize: const Size.square(38),
                  minimumSize: const Size.square(38),
                ),
                icon: Icon(CupertinoIcons.mic, size: 17),
              ),
              const Spacer(),
              if (hasText) ...[
                IconButton(
                  tooltip: 'Clear search',
                  onPressed: onClear,
                  style: IconButton.styleFrom(
                    backgroundColor: AppTheme.bgSurface,
                    foregroundColor: AppTheme.textSecondary,
                    fixedSize: const Size.square(38),
                    minimumSize: const Size.square(38),
                  ),
                  icon: Icon(CupertinoIcons.xmark, size: 18),
                ),
                const SizedBox(width: 8),
              ],
              IconButton(
                tooltip: 'Search',
                onPressed: hasText ? () => onSubmit(null) : null,
                style: IconButton.styleFrom(
                  backgroundColor:
                      hasText ? _AiSearchScreenState._accent : AppTheme.border,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppTheme.border,
                  disabledForegroundColor: AppTheme.textMuted,
                  fixedSize: const Size.square(42),
                  minimumSize: const Size.square(42),
                ),
                icon: Icon(CupertinoIcons.arrow_right, size: 21),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
