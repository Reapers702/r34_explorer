import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:r34_video/constant/page_routes.dart';
import 'package:r34_video/page/component/common/app_search_bar.dart';
import 'package:r34_video/page/component/common/app_state_view.dart';
import 'package:r34_video/page/component/common/section_header.dart';
import 'package:r34_video/page/component/search_select_dialog.dart';
import 'package:r34_video/page/component/video_tag_chip.dart';
import 'package:r34_video/page/search_result_page.dart';
import 'package:r34_video/provider/search_edit_provider.dart';
import 'package:r34_video/repo/r34_search_repo.dart';
import 'package:r34_video/theme/app_colors.dart';
import 'package:r34_video/theme/app_dimens.dart';

class SearchEditPage extends StatefulWidget {
  const SearchEditPage({super.key});

  @override
  State<SearchEditPage> createState() => _SearchEditPageState();
}

class _SearchEditPageState extends State<SearchEditPage> {
  final TextEditingController _controller = TextEditingController();

  /// 附加搜索条件：Tag / 创作者 / 分类 / 屏蔽（temp blacklist）。
  ///
  /// 与原站搜索表单一致：这些条件只在「关键词搜索」时随 `q` 一起下发，
  /// 搜索历史只记录主关键词文本，附加条件不进历史。
  final List<R34VideoAutocompleteItem> _selectedTags = [];
  final List<R34VideoAutocompleteItem> _selectedArtists = [];
  final List<R34VideoAutocompleteItem> _selectedCategories = [];
  final List<R34BlacklistSuggestion> _selectedBlacklist = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final provider = context.read<SearchEditProvider>();
      provider.loadHistory();
      provider.loadTrending();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit(String rawText) {
    final text = rawText.trim();

    // 关键词可为空：仅用 Tag / 创作者 / 分类 / 屏蔽条件也能搜（原站允许）。
    if (text.isEmpty && _noCondition()) {
      _toast('请至少输入关键词，或添加一个 Tag / 创作者 / 分类 / 屏蔽条件');
      return;
    }

    if (text.isNotEmpty) {
      context.read<SearchEditProvider>().addSearchHistory(text);
    }
    Navigator.of(context).pushNamed(
      PageRoutes.searchResultPage,
      arguments: SearchResultPageArgs(
        text,
        tagIds: _selectedTags.map((e) => e.id).toList(),
        artistIds: _selectedArtists.map((e) => e.id).toList(),
        categoryIds: _selectedCategories.map((e) => e.id).toList(),
        blacklistTokens: _selectedBlacklist.map((e) => e.token).toList(),
      ),
    );
  }

  bool _noCondition() =>
      _selectedTags.isEmpty &&
      _selectedArtists.isEmpty &&
      _selectedCategories.isEmpty &&
      _selectedBlacklist.isEmpty;

  /// 弹出通用联想选择对话框，选中的项加入对应条件列表。
  Future<void> _pickCondition<T>({
    required String title,
    required String hintText,
    required Future<List<T>> Function(String keyword) loader,
    required String Function(T item) labelOf,
    String? Function(T item)? sublabelOf,
    required List<T> target,
    required String Function(T item) idOf,
  }) async {
    final item = await showSearchSelectDialog<T>(
      context: context,
      title: title,
      hintText: hintText,
      loader: loader,
      labelOf: labelOf,
      sublabelOf: sublabelOf,
    );
    if (item == null || !mounted) {
      return;
    }
    setState(() {
      final id = idOf(item);
      if (!target.any((e) => idOf(e) == id)) {
        target.add(item);
      }
    });
  }

  void _removeCondition<T>(List<T> target, T item) {
    setState(() => target.remove(item));
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
      );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SearchEditProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        titleSpacing: AppSpacing.page,
        title: Row(
          children: [
            Expanded(
              child: AppSearchBar(
                controller: _controller,
                autofocus: true,
                hintText: '搜点东西试试',
                onSubmitted: _submit,
                onClear: () => _controller.clear(),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            TextButton(
              onPressed: () => _submit(_controller.text),
              child: const Text('搜索'),
            ),
          ],
        ),
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async {
          await provider.loadTrending();
        },
        child: ListView(
          padding: const EdgeInsets.only(bottom: AppSpacing.xl),
          children: [
            _buildConditionPanel(),
            SectionHeader(
              title: '搜索历史',
              trailing: provider.history.isEmpty
                  ? null
                  : TextButton(
                      onPressed: () => provider.clearSearchHistory(),
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        foregroundColor: AppColors.textHint,
                      ),
                      child: const Text(
                        '清空',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
            ),
            if (provider.historyLoading && provider.history.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: AppSkeleton(height: 28),
              )
            else if (provider.history.isEmpty)
              const InlineEmpty('还没有搜索记录')
            else
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.page,
                ),
                child: Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: provider.history
                      .map(
                        (e) => VideoSearchHistoryChip(
                          e,
                          onDelete: () => provider.removeSearchHistory(e),
                        ),
                      )
                      .toList(),
                ),
              ),
            const SectionHeader(title: '热搜 Tag'),
            _buildChipSection(
              loading: provider.trendingLoading,
              empty: provider.trendingTags.isEmpty,
              children: provider.trendingTags
                  .map((e) => VideoTagChip(e))
                  .toList(),
            ),
            const SectionHeader(title: '热搜分类'),
            _buildChipSection(
              loading: provider.trendingLoading,
              empty: provider.trendingCategories.isEmpty,
              children: provider.trendingCategories
                  .map((e) => VideoCategoryChip(e, showAvatar: true))
                  .toList(),
            ),
            const SectionHeader(title: '热搜创作者'),
            _buildChipSection(
              loading: provider.trendingLoading,
              empty: provider.trendingArtists.isEmpty,
              children: provider.trendingArtists
                  .map((e) => VideoArtistChip(e, showAvatar: true))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChipSection({
    required bool loading,
    required bool empty,
    required List<Widget> children,
  }) {
    if (loading && empty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        child: AppSkeleton(height: 28),
      );
    }
    if (empty) {
      return const InlineEmpty('暂时没取到数据，下拉刷新试试');
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: children,
      ),
    );
  }

  /// 搜索条件区：四个入口（+Tag / +创作者 / +分类 / 屏蔽）+ 已选条件 chips。
  Widget _buildConditionPanel() {
    final selectedChips = <Widget>[
      for (final e in _selectedTags)
        AppChip.text(
          e.title,
          selected: true,
          fontSize: 12,
          onDeleted: () => _removeCondition(_selectedTags, e),
        ),
      for (final e in _selectedArtists)
        AppChip.text(
          e.title,
          selected: true,
          fontSize: 12,
          onDeleted: () => _removeCondition(_selectedArtists, e),
        ),
      for (final e in _selectedCategories)
        AppChip.text(
          e.title,
          selected: true,
          fontSize: 12,
          onDeleted: () => _removeCondition(_selectedCategories, e),
        ),
      for (final e in _selectedBlacklist)
        AppChip.text(
          '${e.typeLabel}: ${e.name}',
          selected: true,
          fontSize: 12,
          onDeleted: () => _removeCondition(_selectedBlacklist, e),
        ),
    ];

    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.sm,
        AppSpacing.page,
        AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '搜索条件',
            style: TextStyle(fontSize: 12, color: AppColors.textHint),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              AppChip.text(
                '+ Tag',
                fontSize: 12,
                onTap: () => _pickCondition<R34VideoAutocompleteItem>(
                  title: '添加 Tag',
                  hintText: '输入 Tag 关键字',
                  loader: R34SearchRepo.autocompleteTags,
                  labelOf: (e) => e.title,
                  sublabelOf: (e) =>
                      e.total.isEmpty ? null : '${e.total} 个视频',
                  target: _selectedTags,
                  idOf: (e) => e.id,
                ),
              ),
              AppChip.text(
                '+ 创作者',
                fontSize: 12,
                onTap: () => _pickCondition<R34VideoAutocompleteItem>(
                  title: '添加创作者',
                  hintText: '输入创作者名字',
                  loader: R34SearchRepo.autocompleteArtists,
                  labelOf: (e) => e.title,
                  target: _selectedArtists,
                  idOf: (e) => e.id,
                ),
              ),
              AppChip.text(
                '+ 分类',
                fontSize: 12,
                onTap: () => _pickCondition<R34VideoAutocompleteItem>(
                  title: '添加分类',
                  hintText: '输入分类关键字',
                  loader: R34SearchRepo.autocompleteCategories,
                  labelOf: (e) => e.title,
                  target: _selectedCategories,
                  idOf: (e) => e.id,
                ),
              ),
              AppChip.text(
                '屏蔽',
                fontSize: 12,
                onTap: () => _pickCondition<R34BlacklistSuggestion>(
                  title: '屏蔽（临时黑名单）',
                  hintText: '输入 Tag / 分类 / 创作者',
                  loader: R34SearchRepo.autocompleteBlacklist,
                  labelOf: (e) => '${e.typeLabel}: ${e.name}',
                  target: _selectedBlacklist,
                  idOf: (e) => e.token,
                ),
              ),
            ],
          ),
          if (selectedChips.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: selectedChips,
            ),
          ],
        ],
      ),
    );
  }
}
