import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:r34_video/constant/filter_selection.dart';
import 'package:r34_video/page/component/common/app_filter_chip_bar.dart';
import 'package:r34_video/page/component/common/app_paged_grid_controller.dart';
import 'package:r34_video/page/component/common/app_search_bar.dart';
import 'package:r34_video/page/component/common/app_state_view.dart';
import 'package:r34_video/page/component/common/tag_search_bar.dart';
import 'package:r34_video/page/component/filter_bottom_sheet.dart';
import 'package:r34_video/page/component/video_thumb.dart';
import 'package:r34_video/repo/entity/r34_page.dart' show R34Video;
import 'package:r34_video/repo/entity/r34_search_request.dart';
import 'package:r34_video/repo/r34_search_repo.dart';
import 'package:r34_video/theme/app_colors.dart';
import 'package:r34_video/theme/app_dimens.dart';

/// 搜索结果页参数。
///
/// 前缀约定：`t:` tag、`c:` 分类、`a:` 创作者，其它一律当关键词。
class SearchResultPageArgs {
  final String rawText;
  late final String searchText;
  late final SearchKeywordType keywordType;

  SearchResultPageArgs(this.rawText) {
    if (rawText.startsWith('t:')) {
      searchText = rawText.substring(2);
      keywordType = SearchKeywordType.tag;
    } else if (rawText.startsWith('c:')) {
      searchText = rawText.substring(2);
      keywordType = SearchKeywordType.category;
    } else if (rawText.startsWith('a:')) {
      searchText = rawText.substring(2);
      keywordType = SearchKeywordType.artist;
    } else {
      searchText = rawText;
      keywordType = SearchKeywordType.keyword;
    }
  }

  /// 输入框里展示的文案。
  String get displayText {
    switch (keywordType) {
      case SearchKeywordType.tag:
        return 'Tag: $searchText';
      case SearchKeywordType.category:
        return '分类: $searchText';
      case SearchKeywordType.artist:
        return '创作者: $searchText';
      case SearchKeywordType.keyword:
        return searchText;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'searchText': searchText,
      'keywordType': keywordType.name,
    };
  }
}

class SearchResultPage extends StatefulWidget {
  const SearchResultPage({super.key});

  @override
  State<SearchResultPage> createState() => _SearchResultPageState();
}

class _SearchResultPageState extends State<SearchResultPage> {
  SearchResultPageArgs? _args;
  final PageController _pageController = PageController();

  late R34SearchRequest _search;

  /// 当前已选的 tag（原值；rule34video 的 tag 内部带空格）。
  List<String> _tags = const [];

  /// 是否对当前条件启用 tag 联想。
  ///
  /// 站点自己只在**关键词**搜索上给 tag 联想；tag / 创作者 / 分类页本身就是
  /// 某个 tag 的结果列表，再加一层 tag 联想语义就乱了，所以只对 keyword 开。
  bool get _tagInputEnabled => _search.keywordType == SearchKeywordType.keyword;

  late final AppPagedGridController _grid = AppPagedGridController(
    loader: (page) async {
      final request = _search.duplicate()..page = page;
      final result = await R34SearchRepo.searchResult(request);
      return VideoPageResult(result.videos, result.pageCount);
    },
  );

  @override
  void initState() {
    super.initState();
    _grid.addListener(_onGridChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_args != null) {
      return;
    }

    final arguments = ModalRoute.of(context)?.settings.arguments;
    _args = arguments is SearchResultPageArgs
        ? arguments
        : SearchResultPageArgs('${arguments ?? ''}');

    _search = R34SearchRequest(
      keywordType: _args!.keywordType,
      keyword: _args!.searchText,
    );
    _tags = _initialTags(_args!.searchText);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _grid.loadPage(1);
      }
    });
  }

  /// 初始关键词按空格拆成 chip，让用户一进页面就能看到当前条件。
  ///
  /// 注：rule34video 的 tag 本身可能带空格（`ada wong (resident evil)`），
  /// 拆开只是**展示**成 token；真正搜什么由 [_onTagsChanged] 重新拼。
  List<String> _initialTags(String keyword) {
    final trimmed = keyword.trim();
    if (trimmed.isEmpty || !_tagInputEnabled) {
      return const [];
    }
    return trimmed.split(RegExp(r'\s+'));
  }

  /// tag 条件变化：直接用新的 tag 串作为搜索关键词重新拉取。
  ///
  /// rule34video 的关键词搜索本身就接受带空格的完整 tag，所以这里不需要
  /// 额外变换（与 rule34.xxx 用下划线不同）。
  Future<void> _onTagsChanged(String tags) async {
    final text = tags.trim();
    final next = text.isEmpty ? const <String>[] : text.split(' ');
    if (listEquals(next, _tags)) {
      return;
    }
    setState(() {
      _tags = next;
      _search = R34SearchRequest(
        keywordType: _search.keywordType,
        keyword: text,
        filter: _search.filter,
      );
    });
    await _reload();
  }

  Future<List<TagSuggestion>> _autocomplete(String query) async {
    final list = await R34SearchRepo.autocompleteTags(query);
    return list
        .map((e) => TagSuggestion(
              value: e.title,
              label: e.title,
              count: e.total,
            ))
        .toList();
  }

  @override
  void dispose() {
    _grid.removeListener(_onGridChanged);
    _grid.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _onGridChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _reload() async {
    await _grid.reset();
    if (mounted && _pageController.hasClients) {
      _pageController.jumpToPage(0);
    }
  }

  Future<void> _onSortSelected(HomeSortEnum sort) async {
    if (_search.sortType == sort) {
      return;
    }
    setState(() => _search.sortType = sort);
    await _reload();
  }

  /// 关键词搜索才有「最符合」，其它分类页的服务端不支持这个排序。
  bool get _supportsRelevant => _search.keywordType == SearchKeywordType.keyword;

  Map<String, HomeSortEnum> get _sortOptions => _supportsRelevant
      ? HomeSortEnum.descriptionMapWithSearch
      : HomeSortEnum.descriptionMap;

  Future<void> _openFilter() async {
    final result = await showFilterBottomSheet(
      context: context,
      initial: _search.filter,
      showSort: true,
      sortableRelevant: _supportsRelevant,
    );
    if (result == null || !mounted) {
      return;
    }
    if (result.filterEquals(_search.filter)) {
      _toast('筛选条件没有变化');
      return;
    }
    setState(() => _search.filter = result);
    await _reload();
  }

  Future<void> _clearSecondaryFilter() async {
    setState(() {
      _search.filter = _search.filter.copyWith(
        duration: VideoDuration.all,
        dateAdded: VideoDateAdded.all,
        clearCustomDuration: true,
      );
    });
    await _reload();
  }

  Future<void> _showPageSwitcher() async {
    final controller = TextEditingController();
    final target = await showDialog<int>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('跳到指定页'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(hintText: '1 - ${_grid.pageCount}'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              final page = int.tryParse(controller.text.trim());
              if (page == null || page < 1 || page > _grid.pageCount) {
                _toast('请输入 1 - ${_grid.pageCount} 之间的页码');
                return;
              }
              Navigator.of(dialogContext).pop(page);
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
    controller.dispose();

    if (target != null && mounted && _pageController.hasClients) {
      _pageController.jumpToPage(target - 1);
    }
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
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        titleSpacing: 0,
        title: AppToolbar(
          searchBar: AppSearchBar(
            hintText: _args?.displayText ?? '',
            readOnly: true,
            onTap: () => Navigator.of(context).maybePop(),
          ),
          actions: [
            AppToolbarAction(
              icon: Icons.filter_list_alt,
              tooltip: '筛选',
              badgeCount: _search.filter.activeLabels.length,
              onPressed: _openFilter,
            ),
            AppToolbarAction(
              icon: Icons.last_page_rounded,
              tooltip: '跳到指定页',
              onPressed: _showPageSwitcher,
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          ColoredBox(
            color: AppColors.surface,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // tag 联想：仅在关键词搜索下出现（其它类型本身就是某个 tag 的结果）。
                if (_tagInputEnabled)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.page,
                      AppSpacing.sm,
                      AppSpacing.page,
                      AppSpacing.xs,
                    ),
                    child: TagSearchBar(
                      selectedTags: _tags,
                      rules: TagRules.rule34video,
                      searchTags: _autocomplete,
                      onChanged: _onTagsChanged,
                    ),
                  ),
                AppFilterChipBar(
                  selection: _search.filter,
                  sortOptions: _sortOptions,
                  onSortSelected: _onSortSelected,
                  onOpenFilter: _openFilter,
                  onClearSecondary: _clearSecondaryFilter,
                ),
                const Divider(height: 1),
              ],
            ),
          ),
          Expanded(child: _buildGrid()),
        ],
      ),
    );
  }

  Widget _buildGrid() {
    if (_grid.loading && _grid.videosOf(1).isEmpty) {
      return const VideoGridView([]);
    }

    return PageView.builder(
      controller: _pageController,
      itemCount: _grid.pageCount,
      onPageChanged: (index) => _grid.onPageChanged(index + 1),
      itemBuilder: (context, index) {
        final page = index + 1;
        final videos = _grid.videosOf(page).cast<R34Video>();

        if (videos.isEmpty && _grid.loading) {
          return const VideoGridView([]);
        }

        if (videos.isEmpty) {
          return AppStateView.empty(
            title: '没有搜到内容',
            description: '换个关键词，或者放宽时长 / 时间条件',
            actionLabel: '重新加载',
            onAction: () => _grid.loadPage(page),
          );
        }

        return RefreshIndicator(
          color: AppColors.primary,
          onRefresh: _reload,
          child: VideoGridView(videos),
        );
      },
    );
  }
}
