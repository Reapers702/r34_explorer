import 'package:flutter/material.dart';
import 'package:r34_video/constant/filter_selection.dart';
import 'package:r34_video/page/component/common/section_header.dart';
import 'package:r34_video/theme/app_colors.dart';
import 'package:r34_video/theme/app_dimens.dart';

/// 「排序 + 时长 + 上传时间」筛选面板。
///
/// 首页和搜索结果页共用同一个面板：首页用它筛时长/时间，搜索页在它基础上
/// 还能改排序（搜索页排序条件更多，含「最符合」）。
/// 返回 `null` 表示用户没确认（点遮罩/返回关闭）。
Future<FilterSelection?> showFilterBottomSheet({
  required BuildContext context,
  required FilterSelection initial,
  bool showSort = true,
  bool sortableRelevant = false,
}) {
  return showModalBottomSheet<FilterSelection>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    builder: (context) => FilterBottomSheet(
      initial: initial,
      showSort: showSort,
      sortableRelevant: sortableRelevant,
    ),
  );
}

class FilterBottomSheet extends StatefulWidget {
  final FilterSelection initial;
  final bool showSort;
  final bool sortableRelevant;

  /// 每次改动后回调，方便内嵌使用时实时联动（弹窗形式则直接用返回值）。
  final ValueChanged<FilterSelection>? onChanged;

  const FilterBottomSheet({
    super.key,
    required this.initial,
    this.showSort = true,
    this.sortableRelevant = false,
    this.onChanged,
  });

  @override
  State<FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends State<FilterBottomSheet> {
  late FilterSelection _draft;

  @override
  void initState() {
    super.initState();
    _draft = widget.initial.duplicate();
  }

  /// 改一个条件并通知外部。
  void _update(void Function(FilterSelection draft) mutate) {
    setState(() => mutate(_draft));
    widget.onChanged?.call(_draft);
  }

  List<MapEntry<String, HomeSortEnum>> get _sortOptions {
    final map = widget.sortableRelevant
        ? HomeSortEnum.descriptionMapWithSearch
        : HomeSortEnum.descriptionMap;
    return map.entries.toList();
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final maxHeight = mediaQuery.size.height * 0.82;

    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHandle(),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.showSort) ...[
                      const SectionHeader(
                        title: '排序方式',
                        padding: EdgeInsets.fromLTRB(
                          AppSpacing.lg,
                          AppSpacing.sm,
                          AppSpacing.lg,
                          AppSpacing.sm,
                        ),
                      ),
                      Padding(
                        padding:
                            const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                        child: Wrap(
                          spacing: AppSpacing.sm,
                          runSpacing: AppSpacing.sm,
                          children: _sortOptions
                              .map(
                                (entry) => _FilterRadioChip(
                                  label: entry.key,
                                  selected: _draft.sortType == entry.value,
                                  onTap: () => _update(
                                    (draft) => draft.sortType = entry.value,
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    ],
                    const SectionHeader(
                      title: '视频时长',
                      padding: EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        AppSpacing.lg,
                        AppSpacing.lg,
                        AppSpacing.sm,
                      ),
                    ),
                    Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                      child: Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: [
                          ...VideoDuration.descriptionMap.entries.map(
                            (entry) => _FilterRadioChip(
                              label: entry.key,
                              selected: _draft.duration == entry.value,
                              onTap: () => _update((draft) {
                                draft.duration = entry.value;
                                draft.customFromSeconds = null;
                                draft.customToSeconds = null;
                              }),
                            ),
                          ),
                          _buildCustomDurationChip(),
                        ],
                      ),
                    ),
                    const SectionHeader(
                      title: '上传时间',
                      padding: EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        AppSpacing.lg,
                        AppSpacing.lg,
                        AppSpacing.sm,
                      ),
                    ),
                    Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                      child: Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: VideoDateAdded.descriptionMap.entries
                            .map(
                              (entry) => _FilterRadioChip(
                                label: entry.key,
                                selected: _draft.dateAdded == entry.value,
                                onTap: () => _update(
                                  (draft) => draft.dateAdded = entry.value,
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            _buildActions(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHandle() {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md, bottom: AppSpacing.xs),
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: AppColors.border,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
      ),
    );
  }

  Widget _buildCustomDurationChip() {
    final isCustom = _draft.duration == VideoDuration.custom;
    final label = isCustom ? _customDurationLabel() : '自定义';

    return _FilterRadioChip(
      label: label,
      selected: isCustom,
      icon: isCustom ? Icons.edit_outlined : null,
      onTap: _editCustomDuration,
    );
  }

  String _customDurationLabel() {
    String fmt(int? seconds) {
      if (seconds == null || seconds <= 0) {
        return '不限';
      }
      if (seconds >= 60) {
        final minutes = seconds / 60;
        return minutes == minutes.roundToDouble()
            ? '${minutes.round()}分'
            : '${minutes.toStringAsFixed(1)}分';
      }
      return '$seconds秒';
    }

    return '${fmt(_draft.customFromSeconds)} ~ ${fmt(_draft.customToSeconds)}';
  }

  Future<void> _editCustomDuration() async {
    final fromController = TextEditingController(
      text: _draft.customFromSeconds?.toString() ?? '',
    );
    final toController = TextEditingController(
      text: _draft.customToSeconds?.toString() ?? '',
    );

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        String? errorText;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('自定义时长'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '单位：秒，留空表示不限制',
                    style: TextStyle(fontSize: 12, color: AppColors.textHint),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: fromController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: '最短'),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                        child: Text('~'),
                      ),
                      Expanded(
                        child: TextField(
                          controller: toController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: '最长'),
                        ),
                      ),
                    ],
                  ),
                  if (errorText != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      errorText!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.error,
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('取消'),
                ),
                TextButton(
                  onPressed: () {
                    final from = int.tryParse(fromController.text.trim());
                    final to = int.tryParse(toController.text.trim());
                    if (from != null && to != null && from > to) {
                      setDialogState(() {
                        errorText = '最短时长不能大于最长时长';
                      });
                      return;
                    }
                    _update((draft) {
                      draft.duration = VideoDuration.custom;
                      draft.customFromSeconds = from;
                      draft.customToSeconds = to;
                    });
                    Navigator.of(dialogContext).pop(true);
                  },
                  child: const Text('确定'),
                ),
              ],
            );
          },
        );
      },
    );

    fromController.dispose();
    toController.dispose();

    if (confirmed == true) {
      setState(() {});
    }
  }

  Widget _buildActions(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () {
                final reset = FilterSelection();
                widget.onChanged?.call(reset);
                Navigator.of(context).pop(reset);
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                side: const BorderSide(color: AppColors.border),
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
              ),
              child: const Text('重置'),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            flex: 2,
            child: FilledButton(
              onPressed: () => Navigator.of(context).pop(_draft),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              ),
              child: const Text('应用'),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterRadioChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  const _FilterRadioChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return AppChip.text(
      label,
      selected: selected,
      onTap: onTap,
      leading: icon == null
          ? null
          : Icon(
              icon,
              size: 14,
              color: selected ? AppColors.primary : AppColors.textSecondary,
            ),
    );
  }
}
