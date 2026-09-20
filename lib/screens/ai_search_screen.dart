import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

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
  static const _bg = AppTheme.bg;
  static const _panel = Colors.white;
  static const _panelBorder = AppTheme.borderMid;
  static const _accent = AppTheme.accent;
  static const _text = AppTheme.textPrimary;
  static const _muted = AppTheme.textMuted;

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
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: _bg,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: _bg,
        resizeToAvoidBottomInset: true,
        body: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.white, AppTheme.bg],
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
    Navigator.pop(context, query);
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
                backgroundColor: Colors.white,
                foregroundColor: AppTheme.textPrimary,
                fixedSize: const Size.square(36),
                minimumSize: const Size.square(36),
              ),
              icon: const Icon(CupertinoIcons.chevron_left, size: 20),
            ),
          ),
          const Text(
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
                child: const Center(
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
                  style: const TextStyle(
                    color: _AiSearchScreenState._text,
                    fontSize: 14,
                    height: 1.4,
                  ),
                  decoration: const InputDecoration(
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
                icon: const Icon(CupertinoIcons.mic, size: 17),
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
                  icon: const Icon(CupertinoIcons.xmark, size: 18),
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
                icon: const Icon(CupertinoIcons.arrow_right, size: 21),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
