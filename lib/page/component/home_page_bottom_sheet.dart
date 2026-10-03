import 'package:flutter/material.dart';
import 'package:r34_video/constant/filter_selection.dart';
import 'package:r34_video/page/component/filter_bottom_sheet.dart';

/// 旧版首页筛选底部面板。
///
/// 现在已经统一到 [FilterBottomSheet]（排序 + 时长 + 上传时间，首页与搜索页共用）。
/// 这里保留一个薄封装，避免旧调用点直接失效；新代码请直接用
/// [showFilterBottomSheet]。
@Deprecated('改用 page/component/filter_bottom_sheet.dart 的 showFilterBottomSheet')
class HomePageBottomSheet extends StatelessWidget {
  final VideoDateAdded defaultDateAdded;
  final VideoDuration defaultDuration;
  final void Function(VideoDateAdded dateAdded, VideoDuration duration)?
      onOptionConfirm;

  const HomePageBottomSheet({
    super.key,
    this.onOptionConfirm,
    this.defaultDateAdded = VideoDateAdded.all,
    this.defaultDuration = VideoDuration.all,
  });

  @override
  Widget build(BuildContext context) {
    return FilterBottomSheet(
      initial: FilterSelection(
        duration: defaultDuration,
        dateAdded: defaultDateAdded,
      ),
      showSort: false,
    );
  }
}
