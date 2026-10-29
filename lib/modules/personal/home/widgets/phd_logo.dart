import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

class PHDLogo extends StatelessWidget {
  final double fontSize;
  const PHDLogo({super.key, this.fontSize = 32});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      AppColors.ehClaro ? 'assets/images/logo_black.png' : 'assets/images/logo_white.png',
      height: fontSize * 1.1,
      fit: BoxFit.contain,
    );
  }
}
