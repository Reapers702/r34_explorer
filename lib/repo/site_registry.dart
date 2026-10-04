import 'package:flutter/material.dart';
import 'package:r34_video/page/component/common/app_select_tile.dart';
import 'package:r34_video/theme/app_colors.dart';
import 'package:r34_video/theme/app_dimens.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 可选的站点。
///
/// 两个站内容形态完全不同：
/// * [rule34video] —— 视频站，HTML 抓取 + 风控 cookie，走内置播放器；
/// * [rule34xxx] —— 图片站（Booru），公开 JSON API，看图为主。
///
/// 所以它们各自有独立的首页与详情页，只共享主题和通用组件。
enum R34Site {
  rule34video,
  rule34xxx,
  ;

  String get displayName => {
        rule34video: 'rule34video',
        rule34xxx: 'rule34.xxx',
      }[this]!;

  String get description => {
        rule34video: '视频站 · 需要 cookie',
        rule34xxx: '图片站 · 公开接口',
      }[this]!;

  IconData get icon => {
        rule34video: Icons.play_circle_outline_rounded,
        rule34xxx: Icons.image_outlined,
      }[this]!;
}

/// 当前站点，切换后通知全局重建。
class SiteRegistry extends ChangeNotifier {
  SiteRegistry._();

  static final SiteRegistry instance = SiteRegistry._();

  static const String _prefsKey = 'active_site';

  R34Site _current = R34Site.rule34video;
  bool _loaded = false;

  R34Site get current => _current;

  bool get loaded => _loaded;

  /// 首次进入时读取上次选择。
  Future<void> load() async {
    if (_loaded) {
      return;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefsKey);
      final match = R34Site.values.where((e) => e.name == saved).firstOrNull;
      if (match != null) {
        _current = match;
      }
    } catch (_) {
      // 读不到就用默认值，不算错误。
    } finally {
      _loaded = true;
      notifyListeners();
    }
  }

  Future<void> setSite(R34Site site) async {
    if (_current == site) {
      return;
    }
    _current = site;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, site.name);
    } catch (_) {
      // 持久化失败不影响本次切换。
    }
  }
}

/// 站点切换面板。
Future<void> showSiteSwitcher(BuildContext context) async {
  final registry = SiteRegistry.instance;

  final selected = await showModalBottomSheet<R34Site>(
    context: context,
    backgroundColor: AppColors.surface,
    builder: (sheetContext) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Text(
                '选择站点',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
            ...R34Site.values.map(
              (site) => AppSelectTile<R34Site>(
                value: site,
                selectedValue: registry.current,
                title: site.displayName,
                subtitle: site.description,
                leading: Icon(site.icon, size: 20, color: AppColors.textSecondary),
                onSelected: (value) => Navigator.of(sheetContext).pop(value),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      );
    },
  );

  if (selected != null) {
    await registry.setSite(selected);
  }
}
