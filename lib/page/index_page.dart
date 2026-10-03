import 'package:flutter/material.dart';
import 'package:r34_video/constant/tab_enum.dart';
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

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
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
      body: PageView(
        controller: _pageController,
        onPageChanged: (value) => setState(() => _currentIndex = value),
        children: TabConst.pages,
      ),
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
