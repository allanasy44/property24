import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class InPropBrand extends StatelessWidget {
  const InPropBrand({this.onImage = false, this.compact = false, super.key});

  final bool onImage;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final markSize = compact ? 32.0 : 38.0;
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
              borderRadius: BorderRadius.circular(compact ? 10 : 12),
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
            child: Icon(
              CupertinoIcons.house_fill,
              size: compact ? 17 : 20,
              color: onImage ? AppTheme.accent : Colors.white,
            ),
          ),
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
      ),
    );
  }
}
