import 'package:flutter/material.dart';
import 'package:r34_video/theme/app_colors.dart';

/// 单选文本组件。
///
/// 早期版本用 `ElevatedButton` + 蓝/橙硬编码配色，这里统一成 [AppChip] 的观感，
/// 并且去掉了 `SingleRadioTextController`——选中值由父级 state 持有即可，
/// 多一层 controller 只会带来「两边不同步」的坑。
class SingleRadioText<T> extends StatelessWidget {
  final List<T> values;
  final Map<String, T> nameMap;
  final T? selected;
  final ValueChanged<T>? onSelect;
  final double fontSize;

  const SingleRadioText({
    super.key,
    required this.values,
    required this.nameMap,
    this.selected,
    this.onSelect,
    this.fontSize = 13,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: values.map((value) {
        String name = '';
        for (final entry in nameMap.entries) {
          if (entry.value == value) {
            name = entry.key;
            break;
          }
        }
        final isSelected = selected == value;

        return GestureDetector(
          onTap: onSelect == null ? null : () => onSelect!(value),
          behavior: HitTestBehavior.opaque,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primary.withValues(alpha: 0.12)
                  : AppColors.skeleton,
              borderRadius: BorderRadius.circular(999),
              border: isSelected
                  ? Border.all(color: AppColors.primary.withValues(alpha: 0.35))
                  : null,
            ),
            child: Text(
              name,
              style: TextStyle(
                fontSize: fontSize,
                color: isSelected ? AppColors.primary : AppColors.textPrimary,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
