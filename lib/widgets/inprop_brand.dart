import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class InPropBrand extends StatelessWidget {
  const InPropBrand({this.size = 40, this.onImage = false, super.key});

  static const _aspectRatio = 1360 / 420;

  final double size;
  final bool onImage;

  @override
  Widget build(BuildContext context) {
    const wordmarkStyle = TextStyle(
      fontFamily: 'Montserrat, Poppins, Arial, sans-serif',
      fontSize: 238,
      fontWeight: FontWeight.w800,
      letterSpacing: -11,
    );
    final wordmarkPainter = TextPainter(
      text: const TextSpan(text: 'inprop', style: wordmarkStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    final svgScale = size * 0.9 / 380;

    final logo = SvgPicture.asset(
      'web/inprop-wordmark.svg',
      width: size * _aspectRatio,
      height: size * 0.9,
      fit: BoxFit.contain,
    );
    final taglineColor = onImage ? Colors.white : const Color(0xff102c5c);
    final taglineStyle = TextStyle(
      color: taglineColor,
      fontSize: size * 0.14,
      fontWeight: FontWeight.w800,
      letterSpacing: size * 0.008,
      height: 1,
    );
    final tagline = SizedBox(
      width: wordmarkPainter.width * svgScale,
      height: size * 0.15,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('RENT', style: taglineStyle),
          _taglineDot(),
          Text('BUY', style: taglineStyle),
          _taglineDot(),
          Text('JOBS', style: taglineStyle),
        ],
      ),
    );
    final logoGraphic = onImage
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
                  child: logo,
                ),
              ),
              logo,
            ],
          )
        : logo;
    final brand = SizedBox(
      width: size * _aspectRatio,
      height: size,
      child: Stack(
        children: [
          Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: size * _aspectRatio,
              height: size * 0.9,
              child: logoGraphic,
            ),
          ),
          Positioned(left: svgScale * 485, top: svgScale * 315, child: tagline),
        ],
      ),
    );

    return Semantics(
      label: 'inprop. Rent, buy, jobs.',
      child: brand,
    );
  }

  Widget _taglineDot() => Container(
    width: size * 0.045,
    height: size * 0.045,
    decoration: const BoxDecoration(
      color: Color(0xfff32635),
      shape: BoxShape.circle,
    ),
  );
}
