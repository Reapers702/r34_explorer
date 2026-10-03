import 'package:flutter/material.dart';
import 'package:r34_video/constant/filter_selection.dart';
import 'package:r34_video/page/component/filter_bottom_sheet.dart';

/// 旧版「翻页 + 筛选」底部面板。
///
/// 已由 [FilterBottomSheet] 取代：翻页改成工具栏上的「跳到指定页」，
/// 筛选走统一的筛选面板。这里只保留一层兼容封装。
@Deprecated('改用 page/component/filter_bottom_sheet.dart 的 showFilterBottomSheet')
class PageSearchBottomSheet extends StatelessWidget {
  final void Function(FilterSelection selection) onSearch;

  const PageSearchBottomSheet({super.key, required this.onSearch});

  @override
  Widget build(BuildContext context) {
    return FilterBottomSheet(
      initial: FilterSelection(),
      onChanged: onSearch,
    );
  }
}
