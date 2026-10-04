import 'dart:async';

import 'package:flutter/material.dart';
import 'package:r34_video/page/component/common/section_header.dart';
import 'package:r34_video/theme/app_colors.dart';
import 'package:r34_video/theme/app_dimens.dart';

/// tag 联想的一条候选（与具体站点无关）。
class TagSuggestion {
  /// 真正的 tag，可直接用于搜索，例如 `ada_wong` 或 `ada wong (resident evil)`。
  final String value;

  /// 展示用文案；为 null 时用 [value]。
  final String? label;

  /// 使用量（部分站点会给），仅用于展示。
  final String? count;

  const TagSuggestion({required this.value, this.label, this.count});

  /// 列表里显示的文本。
  String get display => (label ?? value).replaceAll('_', ' ');

  /// 右侧的 `(12345)`，没有就返回 null。
  String? get countText => (count == null || count!.isEmpty) ? null : '($count)';

  @override
  String toString() => 'TagSuggestion($value)';
}

/// 各站点 tag 规则的差异点。
///
/// 实测两个站**正好相反**：
/// * rule34.xxx：tag 内部用**下划线**（`ada_wong`），空格是 tag 之间的分隔符；
/// * rule34video：tag 内部就**带空格**（`ada wong (resident evil)`）。
///
/// 所以「输入怎么变成合法 tag」和「展示成什么」必须按站点配置，不能写死。
class TagRules {
  /// 把用户原始输入规整成搜索用的 tag。
  final String Function(String raw) normalizeInput;

  /// 把 tag 还原成给人看的形式。
  final String Function(String tag) displayName;

  /// 已选多个 tag 时，拼成接口需要的搜索串。
  final String Function(List<String> tags) joinTags;

  /// 提示文案。
  final String hintText;

  const TagRules({
    required this.normalizeInput,
    required this.displayName,
    required this.joinTags,
    required this.hintText,
  });

  /// rule34.xxx：空格/连字符 -> 下划线；展示时下划线换回空格。
  static final TagRules rule34xxx = TagRules(
    normalizeInput: (raw) => raw
        .trim()
        .replaceAll(RegExp(r'[\s\-]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), ''),
    displayName: (tag) => tag.replaceAll('_', ' '),
    joinTags: (tags) => tags.join(' '),
    hintText: '输入 tag，支持联想（如 ada wong）',
  );

  /// rule34video：tag 本身就带空格，原样保留（只压掉多余空白）。
  static final TagRules rule34video = TagRules(
    normalizeInput: (raw) => raw.trim().replaceAll(RegExp(r'\s+'), ' '),
    displayName: (tag) => tag,
    joinTags: (tags) => tags.join(' '),
    hintText: '输入 tag，支持联想（如 ada wong）',
  );
}

/// 通用的 tag 搜索框：**已选 tag 可见** + **输入联想**。
///
/// 两个站共用（差异通过 [rules] 与 [searchTags] 注入），对应站点原有的能力：
/// 选中/排除的 tag 以可删除 chip 列出，输入时给出带使用量的候选。
class TagSearchBar extends StatefulWidget {
  /// 当前已选中的 tag（原值，未做展示转换）。
  final List<String> selectedTags;

  /// 条件变化时回调，给出完整的搜索串（已按 [rules] 拼好）。
  final ValueChanged<String> onChanged;

  /// 站点 tag 规则。
  final TagRules rules;

  /// 联想查询。返回空列表则不弹下拉。
  final Future<List<TagSuggestion>> Function(String query) searchTags;

  /// 可选：显式「搜索」动作（先选好几个 tag 再一起搜）。
  ///
  /// 为 null 时右侧不显示搜索按钮，行为与之前一致（由外部在 onChanged
  /// 里决定何时发请求）。
  final VoidCallback? onSearch;

  const TagSearchBar({
    super.key,
    required this.selectedTags,
    required this.onChanged,
    required this.rules,
    required this.searchTags,
    this.onSearch,
  });

  @override
  State<TagSearchBar> createState() => _TagSearchBarState();
}

class _TagSearchBarState extends State<TagSearchBar> {
  final TextEditingController _controller = TextEditingController();
  final LayerLink _link = LayerLink();
  final OverlayPortalController _overlay = OverlayPortalController();
  final FocusNode _focusNode = FocusNode();

  Timer? _debounce;
  List<TagSuggestion> _suggestions = const [];
  bool _loading = false;
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
    final query = widget.rules.normalizeInput(raw);
    if (query.isEmpty) {
      setState(() {
        _suggestions = const [];
        _loading = false;
      });
      _hideOverlay();
      return;
    }

    setState(() => _loading = true);
    _debounce = Timer(const Duration(milliseconds: 320), () async {
      _pendingQuery = query;
      final result = await widget.searchTags(query);
      // 丢弃过期响应，避免乱序覆盖。
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
  /// `-tag` 表示排除，符合 booru 语法，原样保留前缀。
  void _addTag(String tag) {
    final raw = tag.trim();
    if (raw.isEmpty) {
      return;
    }
    final normalized = raw.startsWith('-')
        ? '-${widget.rules.normalizeInput(raw.substring(1))}'
        : widget.rules.normalizeInput(raw);
    if (normalized.isEmpty || normalized == '-') {
      return;
    }

    _controller.clear();
    setState(() {
      _suggestions = const [];
      _loading = false;
    });
    _hideOverlay();

    if (widget.selectedTags.contains(normalized)) {
      return;
    }
    widget.onChanged(
      widget.rules.joinTags([...widget.selectedTags, normalized]),
    );
  }

  void _removeTag(String tag) {
    final next = widget.selectedTags.where((e) => e != tag).toList();
    widget.onChanged(widget.rules.joinTags(next));
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
            child: _TagInputField(
              controller: _controller,
              focusNode: _focusNode,
              hintText: widget.rules.hintText,
              loading: _loading,
              onChanged: _onTextChanged,
              onSubmit: _addTag,
              onSearch: widget.onSearch,
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
        ...widget.selectedTags.map((tag) {
          final isExclude = tag.startsWith('-');
          final shown = isExclude
              ? '-${widget.rules.displayName(tag.substring(1))}'
              : widget.rules.displayName(tag);
          return AppChip.text(
            shown,
            selected: !isExclude,
            onDeleted: () => _removeTag(tag),
            fontSize: 12,
            // 排除项用弱色区分，符合 booru 直觉。
            color: isExclude ? AppColors.error : null,
            leading: isExclude
                ? const Icon(
                    Icons.block_rounded,
                    size: 12,
                    color: AppColors.error,
                  )
                : null,
          );
        }),
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
                    style: TextStyle(
                        fontSize: 12, color: AppColors.textHint)),
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
      // 不参与焦点请求：点击联想条目时不能抢走输入框焦点。
      // 否则失焦触发 listener 同步收起 overlay，正在点的 InkWell 被卸载，
      // onTap 丢失，表现为「点击联想完全没效果」。
      child: FocusScope(
        canRequestFocus: false,
        child: Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            color: AppColors.surface,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: width, maxHeight: 260),
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
                              item.display,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                          if (item.countText != null)
                            Text(
                              item.countText!,
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
      ),
    );
  }
}

/// 输入框本体：视觉与 `AppSearchBar` 一致，但支持实时输入 + 加载态 + 提交。
class _TagInputField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String hintText;
  final bool loading;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmit;
  final VoidCallback? onSearch;

  const _TagInputField({
    required this.controller,
    required this.focusNode,
    required this.hintText,
    required this.onChanged,
    required this.onSubmit,
    this.onSearch,
    this.loading = false,
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
              onSubmitted: onSubmit,
              // 禁用默认「点击外部即失焦」：点击联想条目时若先失焦，
              // _focusNode 监听器会同步收起 overlay，正在点的条目被卸载，
              // onTap 丢失，表现为「点击联想完全没效果」。
              onTapOutside: (_) {},
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
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                hintStyle: const TextStyle(
                  color: AppColors.textHint,
                  fontSize: 13,
                ),
              ),
            ),
          ),
          if (loading)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 6),
              child: SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          if (onSearch != null) ...[
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 40, minHeight: 36),
              iconSize: 18,
              color: AppColors.primary,
              tooltip: '按已选 tag 搜索',
              onPressed: onSearch,
              icon: const Icon(Icons.search_rounded),
            ),
            const SizedBox(width: AppSpacing.xs),
          ],
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            iconSize: 18,
            color: AppColors.textSecondary,
            tooltip: '添加 tag',
            onPressed: () => onSubmit(controller.text),
            icon: const Icon(Icons.add_rounded),
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
    );
  }
}
