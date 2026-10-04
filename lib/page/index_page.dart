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
class IndexPage extends StatefulWidget {
  const IndexPage({super.key});

  @override
  State<IndexPage> createState() => _IndexPageState();
}

class _IndexPageState extends State<IndexPage> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;

  /// 两个站点内容形态完全不同，首页按当前站点二选一。
  /// （“我的”页共用，因为账号/设置对两边都适用。）
  late R34Site _site = SiteRegistry.instance.current;

  @override
  void initState() {
    super.initState();
    SiteRegistry.instance.addListener(_onSiteChanged);
  }

  void _onSiteChanged() {
    if (mounted) {
      setState(() => _site = SiteRegistry.instance.current);
    }
  }

  @override
  void dispose() {
    SiteRegistry.instance.removeListener(_onSiteChanged);
    _pageController.dispose();
    super.dispose();
  }

  Widget _buildPages() {
    return PageView(
      controller: _pageController,
      onPageChanged: (value) => setState(() => _currentIndex = value),
      children: [
        _site == R34Site.rule34xxx
            ? const R34XxxHomePage()
            : const HomePage(),
        const LocalLibraryPage(),
        const MyInfoPage(),
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
    final tabs = TabConst.tabs.values.toList();

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
            selectedIndex: _currentIndex,
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
