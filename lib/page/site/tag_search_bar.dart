import 'dart:async';

import 'package:flutter/material.dart';
import 'package:r34_video/page/component/common/section_header.dart';
import 'package:r34_video/repo/r34_xxx_repo.dart';
import 'package:r34_video/theme/app_colors.dart';
import 'package:r34_video/theme/app_dimens.dart';

/// rule34.xxx 的 tag 搜索框。
///
/// 对齐站点原有的两处能力（之前缺失）：
/// 1. **已选 tag 可见**：选中的 tag 以可删除 chip 列出，和站点一样一眼看清当前条件；
/// 2. **输入联想**：走官方 `autocomplete.php`（无需鉴权），展示带使用量的候选。
///
/// booru 规范：tag 内部用下划线、空格是分隔符。用户输入 `ada wong` 会被
/// 规整为 `ada_wong`（见 [R34XxxRepo.normalizeTagQuery]），所以中英文输入习惯都能用。
class TagSearchBar extends StatefulWidget {
  /// 当前已选中的 tag（不带修饰符的原值，如 `ada_wong`）。
  final List<String> selectedTags;

  /// 条件变化（增删 tag 或提交输入）时回调，给出完整的 tag 串。
  final ValueChanged<String> onChanged;

  final String hintText;

  const TagSearchBar({
    super.key,
    required this.selectedTags,
    required this.onChanged,
    this.hintText = '输入 tag，支持联想（如 ada wong）',
  });

  /// 把 tag 列表拼成接口需要的 tags 串。
  static String joinTags(List<String> tags) => tags.join(' ');

  @override
  State<TagSearchBar> createState() => _TagSearchBarState();
}

class _TagSearchBarState extends State<TagSearchBar> {
  final TextEditingController _controller = TextEditingController();
  final LayerLink _link = LayerLink();
  final OverlayPortalController _overlay = OverlayPortalController();
  final FocusNode _focusNode = FocusNode();

  Timer? _debounce;
  List<R34XxxTagSuggestion> _suggestions = const [];
  bool _loading = false;

  /// 本次联想对应的输入，用于丢弃过期响应。
  String _pendingQuery = '';

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) {
        _hideOverlay();
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _hideOverlay() {
    if (_overlay.isShowing) {
      _overlay.hide();
    }
  }

  void _onTextChanged(String raw) {
    _debounce?.cancel();
    final query = R34XxxRepo.normalizeTagQuery(raw);
    if (query.isEmpty) {
      setState(() {
        _suggestions = const [];
        _loading = false;
      });
      _hideOverlay();
      return;
    }

    setState(() => _loading = true);
    // 防抖：边打字边请求会把接口打爆，也容易乱序。
    _debounce = Timer(const Duration(milliseconds: 320), () async {
      _pendingQuery = query;
      final result = await R34XxxRepo.autocomplete(query);
      if (!mounted || _pendingQuery != query) {
        return;
      }
      setState(() {
        _suggestions = result;
        _loading = false;
      });
      if (result.isEmpty) {
        _hideOverlay();
      } else {
        _showOverlay();
      }
    });
  }

  void _showOverlay() {
    if (!_overlay.isShowing && mounted) {
      _overlay.show();
    }
  }

  /// 选中一个 tag。
  ///
  /// 不带 `-` 前缀就是普通「包含」；如果用户输入以 `-` 开头，直接沿用，
  /// 因为 `-tag` 在 booru 语法里表示排除，是合法条件。
  void _addTag(String tag) {
    final value = tag.trim();
    if (value.isEmpty) {
      return;
    }
    // 站点自己的 tag 一律是下划线形式。
    final normalized = value.startsWith('-')
        ? '-${R34XxxRepo.normalizeTagQuery(value.substring(1))}'
        : R34XxxRepo.normalizeTagQuery(value);

    if (widget.selectedTags.contains(normalized)) {
      _controller.clear();
      _hideOverlay();
      return;
    }

    final next = [...widget.selectedTags, normalized];
    _controller.clear();
    setState(() {
      _suggestions = const [];
      _loading = false;
    });
    _hideOverlay();
    widget.onChanged(TagSearchBar.joinTags(next));
  }

  void _removeTag(String tag) {
    final next = widget.selectedTags.where((e) => e != tag).toList();
    widget.onChanged(TagSearchBar.joinTags(next));
  }

  void _clearAll() {
    _controller.clear();
    setState(() => _suggestions = const []);
    _hideOverlay();
    widget.onChanged('');
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        CompositedTransformTarget(
          link: _link,
          child: OverlayPortal(
            controller: _overlay,
            overlayChildBuilder: (context) => _buildSuggestionOverlay(),
            child: AppSearchBarLike(
              controller: _controller,
              focusNode: _focusNode,
              hintText: widget.hintText,
              loading: _loading,
              onChanged: _onTextChanged,
              onSubmitted: _addTag,
              onSuffixTap: _addTag,
              suffixIcon: Icons.add_rounded,
            ),
          ),
        ),
        if (widget.selectedTags.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          _buildSelectedTags(),
        ],
      ],
    );
  }

  Widget _buildSelectedTags() {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        ...widget.selectedTags.map(
          (tag) => AppChip.text(
            // 站点展示时把下划线还原成空格，更符合直觉。
            tag.startsWith('-')
                ? '-${tag.substring(1).replaceAll('_', ' ')}'
                : tag.replaceAll('_', ' '),
            selected: true,
            onDeleted: () => _removeTag(tag),
            fontSize: 12,
          ),
        ),
        GestureDetector(
          onTap: _clearAll,
          behavior: HitTestBehavior.opaque,
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.clear_all_rounded,
                    size: 14, color: AppColors.textHint),
                SizedBox(width: 2),
                Text('清空',
                    style:
                        TextStyle(fontSize: 12, color: AppColors.textHint)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSuggestionOverlay() {
    final renderBox = context.findRenderObject() as RenderBox?;
    final width = renderBox?.size.width ?? 320;

    return CompositedTransformFollower(
      link: _link,
      targetAnchor: Alignment.bottomLeft,
      followerAnchor: Alignment.topLeft,
      offset: const Offset(0, 4),
      child: Align(
        alignment: Alignment.topLeft,
        child: Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          color: AppColors.surface,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: width,
              maxHeight: 260,
            ),
            child: ListView.separated(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: _suggestions.length,
              separatorBuilder: (context, index) =>
                  const Divider(height: 1, indent: 12, endIndent: 12),
              itemBuilder: (context, index) {
                final item = _suggestions[index];
                return InkWell(
                  onTap: () => _addTag(item.value),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.tag_rounded,
                            size: 14, color: AppColors.textHint),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            item.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                        if (item.label.contains('('))
                          Text(
                            item.label.substring(
                              item.label.lastIndexOf('('),
                            ),
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textHint,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// 一个和 [AppSearchBar] 视觉一致的输入框，但多了 `onChanged` 与尾部按钮。
///
/// 之所以不直接复用 `AppSearchBar`：那个组件的定位是「点开就跳搜索页」，
/// 而这里需要真正的实时输入 + 联想，两者交互模型不同，硬套会把那边搞复杂。
class AppSearchBarLike extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String hintText;
  final bool loading;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final ValueChanged<String> onSuffixTap;
  final IconData suffixIcon;

  const AppSearchBarLike({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.hintText,
    required this.onChanged,
    required this.onSubmitted,
    required this.onSuffixTap,
    this.loading = false,
    this.suffixIcon = Icons.add_rounded,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const SizedBox(width: AppSpacing.md),
          const Icon(Icons.search_rounded,
              size: 18, color: AppColors.textHint),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              textInputAction: TextInputAction.done,
              onChanged: onChanged,
              onSubmitted: onSubmitted,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: hintText,
                filled: false,
                isDense: true,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 10),
                hintStyle: const TextStyle(
                  color: AppColors.textHint,
                  fontSize: 13,
                ),
              ),
            ),
          ),
          if (loading)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            iconSize: 18,
            color: AppColors.textSecondary,
            tooltip: '添加 tag',
            onPressed: () => onSuffixTap(controller.text),
            icon: Icon(suffixIcon),
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
    );
  }
}
