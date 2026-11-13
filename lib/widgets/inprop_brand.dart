import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class InPropBrand extends StatelessWidget {
  const InPropBrand({this.size = 40, this.onImage = false, super.key});

  static const _aspectRatio = 1600 / 420;

  final double size;
  final bool onImage;

  @override
  Widget build(BuildContext context) {
    final logo = SvgPicture.asset(
      'web/inprop-logo.svg',
      width: size * _aspectRatio,
      height: size,
      fit: BoxFit.contain,
    );

    return Semantics(
      label: 'inprop',
      child: onImage
          ? Stack(
              alignment: Alignment.center,
              children: [
                ImageFiltered(
                  imageFilter: ui.ImageFilter.blur(sigmaX: 2, sigmaY: 2),
                  child: ColorFiltered(
                    colorFilter: const ColorFilter.mode(
                      Colors.white,
                      BlendMode.srcIn,
                    ),
                    child: SvgPicture.asset(
                      'web/inprop-logo.svg',
                      width: size * _aspectRatio,
                      height: size,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                logo,
              ],
            )
          : logo,
    );
  }
}
