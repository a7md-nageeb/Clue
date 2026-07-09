import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class ForgottenThingsLogo extends StatelessWidget {
  final double size;
  final double? width;
  final double? height;
  final String assetPath;

  const ForgottenThingsLogo({
    super.key,
    this.size = 48.0,
    this.width,
    this.height,
    this.assetPath = 'assets/logo.png',
  });

  @override
  Widget build(BuildContext context) {
    if (assetPath.endsWith('.svg')) {
      return SvgPicture.asset(
        assetPath,
        width: width ?? (height == null ? size : null),
        height: height ?? size,
        fit: BoxFit.contain,
      );
    }
    return Image.asset(
      assetPath,
      width: width ?? (height == null ? size : null),
      height: height ?? size,
      fit: BoxFit.contain,
    );
  }
}
