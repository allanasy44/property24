import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class InPropBrand extends StatelessWidget {
  const InPropBrand({this.size = 40, super.key});

  static const _aspectRatio = 1600 / 420;

  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'inprop',
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(size * 0.06),
        ),
        child: SvgPicture.asset(
          'web/favicon.svg',
          width: size * _aspectRatio,
          height: size,
          fit: BoxFit.contain,
          alignment: Alignment.center,
        ),
      ),
    );
  }
}
