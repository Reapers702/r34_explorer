import 'package:flutter/material.dart';
import 'package:r34_video/constant/filter_selection.dart';
import 'package:r34_video/page/component/underlined_text.dart';
import 'package:r34_video/theme/app_colors.dart';
import 'package:r34_video/theme/app_dimens.dart';

/// 列表页顶部那一条「排序」控制区。
///
/// 首页和搜索结果页共用：排序用带下划线动效的单选文本（延续原来的观感，
/// 改成受控）。时长/上传时间/认证上传者等筛选统一进「筛选」按钮
/// （[showFilterBottomSheet]），入口在页面顶部工具栏。
class AppFilterChipBar extends StatelessWidget {
  final FilterSelection selection;

  /// 排序可选项，页面按场景传（搜索页多一个「最符合」）。
  final Map<String, HomeSortEnum> sortOptions;

  final ValueChanged<HomeSortEnum> onSortSelected;

  const AppFilterChipBar({
    super.key,
    required this.selection,
    required this.sortOptions,
    required this.onSortSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.xs,
        AppSpacing.page,
        AppSpacing.xs,
      ),
      child: UnderlinedTextGroup<HomeSortEnum>(
        sortOptions,
        selected: selection.sortType,
        onSelect: onSortSelected,
        fontSize: 12.5,
        underlineColor: AppColors.primary,
      ),
    );
  }
}
