import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class InPropBrand extends StatelessWidget {
  const InPropBrand({
    this.onImage = false,
    this.compact = false,
    this.showWordmark = true,
    this.size,
    super.key,
  });

  final bool onImage;
  final bool compact;
  final bool showWordmark;
  final double? size;

  @override
  Widget build(BuildContext context) {
    final markSize = size ?? (compact ? 32.0 : 38.0);
    final markRadius = compact ? 10.0 : markSize >= 64 ? 20.0 : 12.0;
    final textColor = onImage ? Colors.white : AppTheme.textPrimary;

    return Semantics(
      label: 'inprop',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: markSize,
            height: markSize,
            decoration: BoxDecoration(
              color: onImage ? Colors.white : AppTheme.accent,
              borderRadius: BorderRadius.circular(markRadius),
              boxShadow: onImage
                  ? [
                      BoxShadow(
                        color: Colors.black.withAlpha(38),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(markRadius),
              child: Image.asset(
                'web/favicon.png',
                width: markSize,
                height: markSize,
                fit: BoxFit.cover,
              ),
            ),
          ),
          if (showWordmark) ...[
            SizedBox(width: compact ? 8 : 10),
            Text(
              'inprop',
              style: TextStyle(
                color: textColor,
                fontSize: compact ? 20 : 23,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
                height: 1,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
