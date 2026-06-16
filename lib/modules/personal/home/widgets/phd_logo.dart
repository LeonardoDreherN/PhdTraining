import 'package:flutter/material.dart';

class PHDLogo extends StatelessWidget {
  final double fontSize;
  const PHDLogo({super.key, this.fontSize = 32});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/logo_white.png',
      height: fontSize * 1.1,
      fit: BoxFit.contain,
    );
  }
}
