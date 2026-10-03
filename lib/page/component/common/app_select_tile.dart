import 'package:flutter/material.dart';
import 'package:r34_video/theme/app_colors.dart';
import 'package:r34_video/theme/app_dimens.dart';

/// 单选列表项。
///
/// 替代 `RadioListTile`：Flutter 3.32 起它的 `groupValue` / `onChanged` 已废弃
/// （要求改用 `RadioGroup` 祖先），而这里只需要「一行文字 + 选中打勾」，
/// 自己实现反而更简单、也不受废弃 API 影响。
class AppSelectTile<T> extends StatelessWidget {
  final T value;

  /// 当前选中值。
  final T? selectedValue;

  final String title;
  final String? subtitle;
  final void Function(T value) onSelected;
  final Widget? leading;

  const AppSelectTile({
    super.key,
    required this.value,
    required this.selectedValue,
    required this.title,
    required this.onSelected,
    this.subtitle,
    this.leading,
  });

  bool get _selected => selectedValue == value;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onSelected(value),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: [
            if (leading != null) ...[
              leading!,
              const SizedBox(width: AppSpacing.md),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14.5,
                      color: _selected
                          ? AppColors.primary
                          : AppColors.textPrimary,
                      fontWeight:
                          _selected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textHint,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (_selected)
              const Icon(
                Icons.check_rounded,
                size: 18,
                color: AppColors.primary,
              ),
          ],
        ),
      ),
    );
  }
}
