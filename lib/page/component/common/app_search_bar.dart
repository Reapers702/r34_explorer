import 'package:flutter/material.dart';
import 'package:r34_video/theme/app_colors.dart';
import 'package:r34_video/theme/app_dimens.dart';

/// 顶部搜索输入框。
///
/// 首页、搜索页、搜索结果页三处原本各写一遍 `Container + border + TextField`，
/// 尺寸和圆角还不一致，这里统一。
class AppSearchBar extends StatelessWidget {
  final TextEditingController? controller;
  final String hintText;
  final bool readOnly;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onTap;
  final VoidCallback? onClear;
  final bool autofocus;
  final Widget? prefixIcon;

  const AppSearchBar({
    super.key,
    this.controller,
    this.hintText = '搜点什么',
    this.readOnly = false,
    this.onSubmitted,
    this.onTap,
    this.onClear,
    this.autofocus = false,
    this.prefixIcon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: AppColors.border),
      ),
      child: TextField(
        controller: controller,
        readOnly: readOnly,
        autofocus: autofocus,
        onTap: onTap,
        textInputAction: TextInputAction.search,
        onSubmitted: onSubmitted,
        style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
        decoration: InputDecoration(
          hintText: hintText,
          filled: false,
          isDense: true,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
          prefixIcon: prefixIcon ??
              const Icon(
                Icons.search_rounded,
                size: 18,
                color: AppColors.textHint,
              ),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 34,
            minHeight: 34,
          ),
          suffixIcon: onClear != null
              ? GestureDetector(
                  onTap: onClear,
                  child: const Icon(
                    Icons.close_rounded,
                    size: 16,
                    color: AppColors.textHint,
                  ),
                )
              : null,
          suffixIconConstraints: const BoxConstraints(
            minWidth: 30,
            minHeight: 30,
          ),
        ),
      ),
    );
  }
}

/// 顶部工具条：[搜索框] + 右侧若干图标按钮。
///
/// `SliverAppBar` 里的 `flexibleSpace` 用它铺满，各页面只需要传按钮。
class AppToolbar extends StatelessWidget {
  final Widget searchBar;
  final List<Widget> actions;
  final EdgeInsetsGeometry padding;

  const AppToolbar({
    super.key,
    required this.searchBar,
    this.actions = const [],
    this.padding = const EdgeInsets.symmetric(horizontal: AppSpacing.page),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Expanded(child: searchBar),
          for (final action in actions) ...[
            const SizedBox(width: AppSpacing.xs),
            action,
          ],
        ],
      ),
    );
  }
}

/// 工具条上的图标按钮，统一点击区域。
class AppToolbarAction extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final int? badgeCount;

  const AppToolbarAction({
    super.key,
    required this.icon,
    required this.tooltip,
    this.onPressed,
    this.badgeCount,
  });

  @override
  Widget build(BuildContext context) {
    final button = IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      iconSize: 21,
      color: AppColors.textSecondary,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
      icon: Icon(icon),
    );

    if (badgeCount == null || badgeCount! <= 0) {
      return button;
    }
    return Stack(
      clipBehavior: Clip.none,
      children: [
        button,
        Positioned(
          right: 2,
          top: 4,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Text(
              '$badgeCount',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
