import 'package:flutter/material.dart';
import 'package:r34_video/theme/app_colors.dart';
import 'package:r34_video/theme/app_dimens.dart';

/// 通用的小标题（左侧一条主色竖线 + 文案），可选右侧动作。
class SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(
      AppSpacing.page,
      AppSpacing.lg,
      AppSpacing.page,
      AppSpacing.sm,
    ),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Container(
            width: 3,
            height: 14,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                subtitle!,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textHint,
                ),
              ),
            ),
          ] else
            const Spacer(),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// 可点击的胶囊标签，替换各处手写的 `Chip(backgroundColor: Colors.grey[400])`。
class AppChip extends StatelessWidget {
  final Widget label;
  final VoidCallback? onTap;
  final VoidCallback? onDeleted;
  final bool selected;
  final EdgeInsetsGeometry? padding;

  const AppChip({
    super.key,
    required this.label,
    this.onTap,
    this.onDeleted,
    this.selected = false,
    this.padding,
  });

  /// 纯文字版本。
  factory AppChip.text(
    String text, {
    Key? key,
    VoidCallback? onTap,
    VoidCallback? onDeleted,
    bool selected = false,
    double fontSize = 13,
    Widget? leading,
    Color? color,
  }) {
    return AppChip(
      key: key,
      onTap: onTap,
      onDeleted: onDeleted,
      selected: selected,
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (leading != null) ...[leading, const SizedBox(width: 6)],
          Text(
            text,
            style: TextStyle(
              fontSize: fontSize,
              color: selected ? AppColors.primary : (color ?? AppColors.textPrimary),
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final child = Container(
      padding: padding ??
          const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: selected
            ? AppColors.primary.withValues(alpha: 0.12)
            : AppColors.skeleton,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: selected
            ? Border.all(color: AppColors.primary.withValues(alpha: 0.35))
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          label,
          if (onDeleted != null) ...[
            const SizedBox(width: 2),
            GestureDetector(
              onTap: onDeleted,
              behavior: HitTestBehavior.opaque,
              child: const Padding(
                padding: EdgeInsets.all(2),
                child: Icon(
                  Icons.close_rounded,
                  size: 14,
                  color: AppColors.textHint,
                ),
              ),
            ),
          ],
        ],
      ),
    );

    if (onTap == null) {
      return child;
    }
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: child,
    );
  }
}

/// 空数据时在区块位置显示一行提示。
class InlineEmpty extends StatelessWidget {
  final String text;
  const InlineEmpty(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.page,
        vertical: AppSpacing.sm,
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 13, color: AppColors.textHint),
      ),
    );
  }
}
