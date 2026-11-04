import 'package:flutter/material.dart';

/// 과제헌터.html(docs/design) 디자인 토큰
abstract final class AppColors {
  static const sage = Color(0xFF779586);
  static const sageDark = Color(0xFF496E59);
  static const sageSoft = Color(0xFFE8EEE9);
  static const cream = Color(0xFFF5F3F0);
  static const border = Color(0xFFE7E5E1);
  static const ink = Color(0xFF252525);
  static const secondary = Color(0xFF77746F);

  static const tagline = Color(0xFF96928E);
  static const muted = Color(0xFF88837E);
  static const placeholder = Color(0xFF8C8984);
  static const subtab = Color(0xFF85817B);
  static const originalText = Color(0xFF575650);
  static const description = Color(0xFF69655F);
  static const noticeText = Color(0xFF5D5A55);
  static const summaryText = Color(0xFF55534F);
  static const timeInput = Color(0xFF817D78);
  static const unitHint = Color(0xFF8A8580);
  static const track = Color(0xFFDEDBD7);
  static const minimize = Color(0xFF6F6E6B);
  static const scrollbar = Color(0xFFD7D6D3);
  static const error = Color(0xFFA94442);
  static const warning = Color(0xFFB98A2E);
  static const toast = Color(0xFF2C332D);
  static const stage = Color(0xFF171717);
}

/// 디자인의 font-size: calc(14px * scale) 기준. em 단위를 그대로 옮긴다.
/// 글자 크기 설정(60~180%)은 위젯 전체에 TextScaler로 곱해진다.
const double kBaseFontSize = 14;

TextStyle em(
  double value, {
  FontWeight weight = FontWeight.w400,
  Color color = AppColors.ink,
  double? height,
  double? letterSpacing,
}) {
  return TextStyle(
    fontSize: kBaseFontSize * value,
    fontWeight: weight,
    color: color,
    height: height,
    letterSpacing: letterSpacing,
  );
}

ThemeData buildAppTheme() {
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    fontFamily: 'Pretendard',
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.sage,
      primary: AppColors.sage,
      surface: Colors.white,
    ),
    scaffoldBackgroundColor: Colors.transparent,
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    hoverColor: Colors.transparent,
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(bodyColor: AppColors.ink, displayColor: AppColors.ink),
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: AppColors.sage,
      selectionColor: Color(0x55779586),
      selectionHandleColor: AppColors.sage,
    ),
    scrollbarTheme: ScrollbarThemeData(
      thickness: WidgetStateProperty.all(4),
      radius: const Radius.circular(8),
      thumbColor: WidgetStateProperty.all(AppColors.scrollbar),
      crossAxisMargin: 2,
    ),
    tooltipTheme: const TooltipThemeData(waitDuration: Duration(milliseconds: 600)),
  );
}
