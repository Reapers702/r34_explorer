import 'package:flutter/material.dart';
import 'package:r34_video/constant/tab_enum.dart';
import 'package:r34_video/page/home_page.dart';
import 'package:r34_video/page/local_library_page.dart';
import 'package:r34_video/page/my_info_page.dart';
import 'package:r34_video/page/site/r34_xxx_home_page.dart';
import 'package:r34_video/repo/site_registry.dart';
import 'package:r34_video/theme/app_colors.dart';

/// 底部导航 + PageView 主框架。
///
/// 早期是手写的 `Row + GestureDetector`，点击热区只有图标大小；
/// 换成 Material 3 的 [NavigationBar] 后水波纹、无障碍、安全区都由框架处理。
///
/// 站点不同，底部导航项也不同：
/// * [R34Site.rule34video] —— 首页 / 收藏 / 我的（3 项）
/// * [R34Site.rule34xxx]   —— 首页 / 收藏（2 项，无「我的」）
/// 切换站点时若当前页在越界索引，自动回落到首页。
class IndexPage extends StatefulWidget {
  const IndexPage({super.key});

  @override
  State<IndexPage> createState() => _IndexPageState();
}

class _IndexPageState extends State<IndexPage> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;

  late R34Site _site = SiteRegistry.instance.current;

  @override
  void initState() {
    super.initState();
    SiteRegistry.instance.addListener(_onSiteChanged);
  }

  /// 当前站点对应的底部导航项。
  List<MapEntry<String, IconData>> _tabsOf(R34Site site) {
    final all = TabConst.tabs.values.toList();
    // rule34.xxx 只有 首页 / 收藏。
    if (site == R34Site.rule34xxx) {
      return all.where((e) => e.key != TabConst.userTabLabel).toList();
    }
    return all;
  }

  void _onSiteChanged() {
    if (!mounted) {
      return;
    }
    final next = SiteRegistry.instance.current;
    // 用目标站点计算可用 Tab 数：切到 Tab 更少的站点时，若当前页越界则回落首页，
    // 否则 PageView 卸载多余页会触发 _InactiveElements._unmount 异常。
    final maxIndex = _tabsOf(next).length - 1;
    final nextIndex = _currentIndex > maxIndex ? 0 : _currentIndex;
    setState(() {
      _site = next;
      if (nextIndex != _currentIndex) {
        _currentIndex = nextIndex;
        _pageController.jumpToPage(nextIndex);
      }
    });
  }

  @override
  void dispose() {
    SiteRegistry.instance.removeListener(_onSiteChanged);
    _pageController.dispose();
    super.dispose();
  }

  Widget _buildPages() {
    final hasUser = _site == R34Site.rule34video;
    return PageView(
      controller: _pageController,
      onPageChanged: (value) => setState(() => _currentIndex = value),
      children: [
        _site == R34Site.rule34xxx
            ? const R34XxxHomePage()
            : const HomePage(),
        const LocalLibraryPage(),
        if (hasUser) const MyInfoPage(),
      ],
    );
  }

  void _onSelect(int index) {
    if (index == _currentIndex) {
      return;
    }
    setState(() => _currentIndex = index);
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final tabs = _tabsOf(_site);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: _buildPages(),
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.divider)),
        ),
        child: NavigationBarTheme(
          data: NavigationBarThemeData(
            height: 58,
            backgroundColor: AppColors.surface,
            indicatorColor: AppColors.primary.withValues(alpha: 0.12),
            labelTextStyle: WidgetStateProperty.resolveWith(
              (states) => TextStyle(
                fontSize: 11,
                fontWeight: states.contains(WidgetState.selected)
                    ? FontWeight.w600
                    : FontWeight.w400,
                color: states.contains(WidgetState.selected)
                    ? AppColors.primary
                    : AppColors.textSecondary,
              ),
            ),
            iconTheme: WidgetStateProperty.resolveWith(
              (states) => IconThemeData(
                size: 22,
                color: states.contains(WidgetState.selected)
                    ? AppColors.primary
                    : AppColors.textSecondary,
              ),
            ),
          ),
          child: NavigationBar(
            selectedIndex: _currentIndex.clamp(0, tabs.length - 1),
            onDestinationSelected: _onSelect,
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            destinations: tabs
                .map(
                  (entry) => NavigationDestination(
                    icon: Icon(entry.value),
                    label: entry.key,
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
  }
}
