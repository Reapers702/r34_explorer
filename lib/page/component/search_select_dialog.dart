import 'dart:async';

import 'package:flutter/material.dart';
import 'package:r34_video/theme/app_colors.dart';
import 'package:r34_video/theme/app_dimens.dart';

/// 通用联想选择对话框：输入关键字 → 防抖联想 → 点选返回。
///
/// 搜索编辑页的「+Tag / +创作者 / +分类 / 屏蔽」共用它，区别只在
/// [loader]（走哪个联想端点）和展示文案。
Future<T?> showSearchSelectDialog<T>({
  required BuildContext context,
  required String title,
  required String hintText,
  required Future<List<T>> Function(String keyword) loader,
  required String Function(T item) labelOf,
  String? Function(T item)? sublabelOf,
}) {
  return showDialog<T>(
    context: context,
    builder: (dialogContext) => _SearchSelectDialog<T>(
      title: title,
      hintText: hintText,
      loader: loader,
      labelOf: labelOf,
      sublabelOf: sublabelOf,
    ),
  );
}

class _SearchSelectDialog<T> extends StatefulWidget {
  final String title;
  final String hintText;
  final Future<List<T>> Function(String keyword) loader;
  final String Function(T item) labelOf;
  final String? Function(T item)? sublabelOf;

  const _SearchSelectDialog({
    required this.title,
    required this.hintText,
    required this.loader,
    required this.labelOf,
    this.sublabelOf,
  });

  @override
  State<_SearchSelectDialog<T>> createState() => _SearchSelectDialogState<T>();
}

class _SearchSelectDialogState<T> extends State<_SearchSelectDialog<T>> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;

  /// 联想请求代数：只采纳最新一次响应的结果，防止旧请求晚到覆盖新输入。
  int _generation = 0;
  bool _loading = false;
  List<T> _items = const [];

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String text) {
    _debounce?.cancel();
    final generation = ++_generation;
    _debounce = Timer(const Duration(milliseconds: 250), () {
      final keyword = text.trim();
      if (keyword.isEmpty) {
        setState(() {
          _loading = false;
          _items = const [];
        });
        return;
      }
      setState(() => _loading = true);
      widget.loader(keyword).then((items) {
        if (!mounted || generation != _generation) {
          return;
        }
        setState(() {
          _items = items;
          _loading = false;
        });
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title, style: const TextStyle(fontSize: 16)),
      content: SizedBox(
        width: double.maxFinite,
        height: 340,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _controller,
              autofocus: true,
              onChanged: _onChanged,
              textInputAction: TextInputAction.search,
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                hintText: widget.hintText,
                hintStyle: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textHint,
                ),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: 8,
                ),
                prefixIcon: const Icon(Icons.search_rounded, size: 18),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  borderSide: const BorderSide(color: AppColors.primary),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Expanded(child: _buildResult()),
          ],
        ),
      ),
    );
  }

  Widget _buildResult() {
    if (_loading && _items.isEmpty) {
      return const Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    if (_items.isEmpty) {
      return Center(
        child: Text(
          _controller.text.trim().isEmpty
              ? '输入关键字联想候选'
              : '没有匹配的候选',
          style: const TextStyle(fontSize: 13, color: AppColors.textHint),
        ),
      );
    }
    return ListView.builder(
      itemCount: _items.length,
      itemBuilder: (context, index) {
        final item = _items[index];
        final sublabel = widget.sublabelOf?.call(item);
        return ListTile(
          dense: true,
          visualDensity: VisualDensity.compact,
          title: Text(
            widget.labelOf(item),
            style: const TextStyle(fontSize: 14),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: sublabel == null || sublabel.isEmpty
              ? null
              : Text(
                  sublabel,
                  style: const TextStyle(fontSize: 12, color: AppColors.textHint),
                ),
          onTap: () => Navigator.of(context).pop(item),
        );
      },
    );
  }
}
