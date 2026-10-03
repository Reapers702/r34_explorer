import 'package:flutter/material.dart';
import 'package:r34_video/constant/filter_selection.dart';
import 'package:r34_video/page/component/common/section_header.dart';
import 'package:r34_video/page/component/underlined_text.dart';
import 'package:r34_video/theme/app_colors.dart';
import 'package:r34_video/theme/app_dimens.dart';

/// 列表页顶部那一条「排序 + 筛选」控制区。
///
/// 首页和搜索结果页共用：
/// * 排序用带下划线动效的单选文本（延续原来的观感，但改成受控）；
/// * 时长/上传时间通过「筛选」按钮打开 [showFilterBottomSheet]；
/// * 有额外条件时显示可一键清除的标签。
class AppFilterChipBar extends StatelessWidget {
  final FilterSelection selection;

  /// 排序可选项，页面按场景传（搜索页多一个「最符合」）。
  final Map<String, HomeSortEnum> sortOptions;

  final ValueChanged<HomeSortEnum> onSortSelected;

  /// 点「筛选」。
  final VoidCallback onOpenFilter;

  /// 点「清除」。
  final VoidCallback onClearSecondary;

  /// 是否显示排序区。
  final bool showSort;

  const AppFilterChipBar({
    super.key,
    required this.selection,
    required this.sortOptions,
    required this.onSortSelected,
    required this.onOpenFilter,
    required this.onClearSecondary,
    this.showSort = true,
  });

  @override
  Widget build(BuildContext context) {
    final labels = selection.activeLabels;
    final hasFilter = labels.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.xs,
        AppSpacing.page,
        AppSpacing.xs,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showSort)
            UnderlinedTextGroup<HomeSortEnum>(
              sortOptions,
              selected: selection.sortType,
              onSelect: onSortSelected,
              fontSize: 12.5,
              underlineColor: AppColors.primary,
            ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            height: 28,
            child: Row(
              children: [
                AppChip.text(
                  hasFilter
                      ? (labels.length == 1
                          ? labels.first
                          : '${labels.first} +${labels.length - 1}')
                      : '时长 / 时间',
                  selected: hasFilter,
                  onTap: onOpenFilter,
                  fontSize: 12,
                  leading: Icon(
                    Icons.tune_rounded,
                    size: 13,
                    color: hasFilter ? AppColors.primary : AppColors.textHint,
                  ),
                ),
                const Spacer(),
                if (hasFilter)
                  GestureDetector(
                    onTap: onClearSecondary,
                    behavior: HitTestBehavior.opaque,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: AppSpacing.xs,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.restart_alt_rounded,
                            size: 14,
                            color: AppColors.textHint,
                          ),
                          SizedBox(width: 2),
                          Text(
                            '清除',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textHint,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
