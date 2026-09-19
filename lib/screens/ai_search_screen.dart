import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:unicons/unicons.dart';

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
  static const _bg = Color(0xff070706);
  static const _panel = Color(0xff191a17);
  static const _panelBorder = Color(0xff5a3422);
  static const _orange = Color(0xffff6f1a);
  static const _text = Color(0xfff5f2ec);
  static const _muted = Color(0xff888883);
  static const _disabled = Color(0xff343431);

  static const _suggestions = [
    _SearchSuggestion('Whole house in Denver for four guests'),
    _SearchSuggestion('Under \$250 a night with free parking'),
    _SearchSuggestion('Walkable to the light rail and a park'),
    _SearchSuggestion('Pet-friendly with a fenced garden', enabled: false),
    _SearchSuggestion('Free cancellation, self check-in', enabled: false),
  ];

  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialQuery);
    _focusNode = FocusNode();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: _bg,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: _bg,
        resizeToAvoidBottomInset: true,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SearchHeader(onBack: () => Navigator.pop(context)),
                const SizedBox(height: 18),
                _PromptBox(
                  controller: _controller,
                  focusNode: _focusNode,
                  onSubmit: _submit,
                ),
                const SizedBox(height: 20),
                const Text(
                  'TRY ASKING',
                  style: TextStyle(
                    color: _muted,
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 12),
                for (final suggestion in _suggestions)
                  _SuggestionTile(
                    suggestion: suggestion,
                    onTap: suggestion.enabled
                        ? () => _submit(suggestion.label)
                        : null,
                  ),
              ],
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
                backgroundColor: const Color(0xff1b1c19),
                foregroundColor: Colors.white,
                fixedSize: const Size.square(36),
                minimumSize: const Size.square(36),
              ),
              icon: const Icon(Icons.chevron_left_rounded, size: 20),
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
    required this.onSubmit,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String?> onSubmit;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 108,
      padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
      decoration: BoxDecoration(
        color: _AiSearchScreenState._panel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _AiSearchScreenState._panelBorder),
        boxShadow: [
          BoxShadow(
            color: _AiSearchScreenState._orange.withOpacity(0.12),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 19,
                width: 19,
                margin: const EdgeInsets.only(top: 2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: _AiSearchScreenState._orange),
                ),
                child: const Center(
                  child: Icon(
                    Icons.circle,
                    color: _AiSearchScreenState._orange,
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
                  maxLines: 2,
                  textInputAction: TextInputAction.search,
                  cursorColor: _AiSearchScreenState._orange,
                  style: const TextStyle(
                    color: _AiSearchScreenState._text,
                    fontSize: 12,
                    height: 1.35,
                  ),
                  decoration: const InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    hintText: 'Describe the stay you are looking for...',
                    hintStyle: TextStyle(
                      color: _AiSearchScreenState._muted,
                      fontSize: 12,
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
                  backgroundColor: const Color(0xff2b2c29),
                  foregroundColor: Colors.white,
                  fixedSize: const Size.square(34),
                  minimumSize: const Size.square(34),
                ),
                icon: const Icon(UniconsLine.microphone, size: 15),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Search',
                onPressed: () => onSubmit(null),
                style: IconButton.styleFrom(
                  backgroundColor: _AiSearchScreenState._orange,
                  foregroundColor: Colors.white,
                  fixedSize: const Size.square(38),
                  minimumSize: const Size.square(38),
                ),
                icon: const Icon(Icons.play_arrow_rounded, size: 22),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SuggestionTile extends StatelessWidget {
  const _SuggestionTile({
    required this.suggestion,
    required this.onTap,
  });

  final _SearchSuggestion suggestion;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = suggestion.enabled
        ? _AiSearchScreenState._text
        : _AiSearchScreenState._disabled;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(
              Icons.search,
              size: 13,
              color: suggestion.enabled
                  ? _AiSearchScreenState._muted
                  : _AiSearchScreenState._disabled,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                suggestion.label,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight:
                      suggestion.enabled ? FontWeight.w500 : FontWeight.w400,
                  letterSpacing: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchSuggestion {
  const _SearchSuggestion(this.label, {this.enabled = true});

  final String label;
  final bool enabled;
}
