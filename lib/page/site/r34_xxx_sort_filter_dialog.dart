import 'package:flutter/material.dart';
import 'package:r34_video/page/site/r34_xxx_search_options.dart';
import 'package:r34_video/theme/app_colors.dart';
import 'package:r34_video/theme/app_dimens.dart';

/// 「排序与筛选」对话框（参考 kurosearch 的 Sorting and Filtering）。
///
/// 修改只回传一组新的 [R34XxxSearchOptions]，**不**触发搜索——
/// 与 tag 一样进待提交区，由用户点「搜索」按钮才生效。
///
/// 用法：
/// ```dart
/// final next = await R34XxxSortFilterDialog.show(context, current);
/// if (next != null) setState(() => _options = next);
/// ```
class R34XxxSortFilterDialog extends StatefulWidget {
  final R34XxxSearchOptions initial;

  const R34XxxSortFilterDialog({super.key, required this.initial});

  /// 弹出对话框；用户点「完成」返回新选项，点「重置」返回默认选项，
  /// 关闭/点遮罩返回 null。
  static Future<R34XxxSearchOptions?> show(
    BuildContext context,
    R34XxxSearchOptions initial,
  ) {
    return showDialog<R34XxxSearchOptions>(
      context: context,
      builder: (context) => R34XxxSortFilterDialog(initial: initial),
    );
  }

  @override
  State<R34XxxSortFilterDialog> createState() => _R34XxxSortFilterDialogState();
}

class _R34XxxSortFilterDialogState extends State<R34XxxSortFilterDialog> {
  late R34XxxSort _sort;
  late bool _enableScore;
  late R34XxxScoreCompare _compare;
  late final TextEditingController _scoreController;
  late R34XxxRating _rating;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _sort = initial.sort;
    _enableScore = initial.minScore != null;
    _compare = initial.scoreCompare;
    _scoreController =
        TextEditingController(text: initial.minScore?.toString() ?? '');
    _rating = initial.rating;
  }

  @override
  void dispose() {
    _scoreController.dispose();
    super.dispose();
  }

  /// 把当前表单状态整理成选项；评分栏打开但数字无效时返回 null。
  R34XxxSearchOptions? _buildOptions() {
    final minScore = int.tryParse(_scoreController.text.trim());
    if (_enableScore && (minScore == null || minScore < 0)) {
      return null;
    }
    return R34XxxSearchOptions(
      sort: _sort,
      minScore: _enableScore ? minScore : null,
      scoreCompare: _compare,
      rating: _rating,
    );
  }

  void _reset() {
    setState(() {
      _sort = R34XxxSort.latest;
      _enableScore = false;
      _compare = R34XxxScoreCompare.gte;
      _scoreController.clear();
      _rating = R34XxxRating.all;
    });
  }

  void _done() {
    final options = _buildOptions();
    if (options == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('评分下限需要是 ≥ 0 的数字')),
      );
      return;
    }
    Navigator.of(context).pop(options);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: const Text('排序与筛选'),
      content: SizedBox(
        width: 340,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '排序',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            _Dropdown<R34XxxSort>(
              value: _sort,
              items: R34XxxSort.values,
              labelOf: (v) => v.label,
              onChanged: (v) => setState(() => _sort = v),
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    '评分下限',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                Switch(
                  value: _enableScore,
                  activeThumbColor: AppColors.primary,
                  onChanged: (v) => setState(() => _enableScore = v),
                ),
              ],
            ),
            if (_enableScore) ...[
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  _Dropdown<R34XxxScoreCompare>(
                    value: _compare,
                    items: R34XxxScoreCompare.values,
                    labelOf: (v) => v.label,
                    onChanged: (v) => setState(() => _compare = v),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: TextField(
                      controller: _scoreController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        isDense: true,
                        border: OutlineInputBorder(),
                        hintText: '如 1000',
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            const Text(
              '评级',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            _Dropdown<R34XxxRating>(
              value: _rating,
              items: R34XxxRating.values,
              labelOf: (v) => v.label,
              onChanged: (v) => setState(() => _rating = v),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _reset,
          child: const Text('重置', style: TextStyle(color: AppColors.textSecondary)),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
          ),
          onPressed: _done,
          child: const Text('完成'),
        ),
      ],
    );
  }
}

/// 带下划线样式的下拉选择（与 AppChip 的选中态视觉一致）。
class _Dropdown<T> extends StatelessWidget {
  final T value;
  final List<T> items;
  final String Function(T) labelOf;
  final ValueChanged<T> onChanged;

  const _Dropdown({
    required this.value,
    required this.items,
    required this.labelOf,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.skeleton,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isDense: true,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          icon: const Icon(Icons.expand_more_rounded, size: 18),
          style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
          items: [
            for (final item in items)
              DropdownMenuItem<T>(value: item, child: Text(labelOf(item))),
          ],
          onChanged: (v) {
            if (v != null) {
              onChanged(v);
            }
          },
        ),
      ),
    );
  }
}
