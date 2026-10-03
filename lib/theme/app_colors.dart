import 'package:flutter/material.dart';

/// 全站配色。
///
/// 早期版本里颜色散落在各个页面（`Colors.grey.shade800`、`Colors.pinkAccent`…），
/// 换一次主题要改十几处。这里集中收口，页面只引用语义化名字。
class AppColors {
  const AppColors._();

  /// 品牌主色。
  static const Color primary = Color(0xFFE5397F);
  static const Color primaryDark = Color(0xFFC42A69);

  /// 强调色，用于选中态下划线。
  static const Color accent = Color(0xFFFF6FA5);

  /// 页面底色。
  static const Color background = Color(0xFFF6F7F9);
  static const Color surface = Color(0xFFFFFFFF);

  /// 播放器区域底色。
  static const Color playerBackground = Color(0xFF000000);

  static const Color textPrimary = Color(0xFF1D1E20);
  static const Color textSecondary = Color(0xFF5C5F66);
  static const Color textHint = Color(0xFF9AA0A6);

  static const Color divider = Color(0xFFEBEDF0);
  static const Color border = Color(0xFFE2E5E9);

  /// 卡片 / 骨架屏底色。
  static const Color skeleton = Color(0xFFE9ECF0);

  /// 浮层蒙层。
  static const Color scrim = Color(0x66000000);

  /// 时长、分辨率角标底色。
  static const Color badgeBackground = Color(0xCC000000);

  static const Color success = Color(0xFF2E9E5B);
  static const Color warning = Color(0xFFF0A020);
  static const Color error = Color(0xFFD94A4A);

  /// 深色播放页使用。
  static const Color onDark = Color(0xFFFFFFFF);
  static const Color onDarkSecondary = Color(0xB3FFFFFF);
}
