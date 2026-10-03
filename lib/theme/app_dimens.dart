/// 统一间距与圆角。
///
/// 早期代码里到处是 `SizedBox(height: 8)`、`BorderRadius.circular(12)` 这类魔法数字，
/// 这里给出常用档位，新代码优先复用。
class AppSpacing {
  const AppSpacing._();

  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;

  /// 页面左右安全边距。
  static const double page = 12;
}

class AppRadius {
  const AppRadius._();

  static const double xs = 6;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double pill = 999;
}

class AppSizes {
  const AppSizes._();

  /// 首页/搜索结果的两列网格。
  static const int gridColumns = 2;

  /// 横滑社区视频卡的封面宽度。
  static const double communityThumbWidth = 152;

  static const int searchHistoryMax = 20;
}
