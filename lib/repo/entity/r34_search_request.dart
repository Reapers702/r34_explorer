import 'package:r34_video/constant/filter_selection.dart';

/// 搜索类型。`keyword` 走站点的搜索接口，其余三种是对应分类页。
enum SearchKeywordType {
  keyword,
  tag,
  artist,
  category,
  ;

  String get desc => {
        keyword: '关键词',
        tag: 'Tag',
        artist: '创作者',
        category: '分类',
      }[this]!;
}

class R34SearchRequest {
  final SearchKeywordType keywordType;
  final String keyword;

  /// 排序 + 时长 + 上传时间，和首页共用同一套筛选模型。
  ///
  /// 之前这里只有 `sortType` 和 `duration`，UI 上也只暴露了排序按钮，
  /// 所以「关键词搜完就没法再加时长/时间条件」。
  FilterSelection filter;

  /// 附加条件，只在 [SearchKeywordType.keyword] 时随 `q` 一起下发
  /// （对齐原站搜索表单：`tag_ids=all,<ids>`、`model_ids=<ids>`、
  /// `category_ids=all,<ids>`、`temp_skip_items=<tokens>`）。
  final List<String> tagIds;
  final List<String> artistIds;
  final List<String> categoryIds;

  /// temp blacklist token，形如 `tag:51` / `cat:3` / `model:8`。
  final List<String> blacklistTokens;

  int page;

  R34SearchRequest({
    required this.keywordType,
    required this.keyword,
    FilterSelection? filter,
    this.tagIds = const [],
    this.artistIds = const [],
    this.categoryIds = const [],
    this.blacklistTokens = const [],
    this.page = 1,
  }) : filter = filter ?? FilterSelection(sortType: HomeSortEnum.mostRelevant);

  HomeSortEnum get sortType => filter.sortType;

  set sortType(HomeSortEnum value) => filter.sortType = value;

  /// 是否有附加条件（tag / 创作者 / 分类 / 屏蔽）。
  bool get hasExtraConditions =>
      tagIds.isNotEmpty ||
      artistIds.isNotEmpty ||
      categoryIds.isNotEmpty ||
      blacklistTokens.isNotEmpty;

  /// 供 UI 展示的搜索条件摘要。
  Map<String, dynamic> toJson() {
    return {
      'keywordType': keywordType.name,
      'keyword': keyword,
      'tagIds': tagIds,
      'artistIds': artistIds,
      'categoryIds': categoryIds,
      'blacklistTokens': blacklistTokens,
      'page': page,
      'filter': filter.toString(),
    };
  }

  /// 是否是同一组搜索条件（[ignorePage] 为 true 时忽略页码）。
  bool equals(R34SearchRequest? other, {bool ignorePage = false}) {
    if (other == null) {
      return false;
    }
    return keywordType == other.keywordType &&
        keyword == other.keyword &&
        _listEquals(tagIds, other.tagIds) &&
        _listEquals(artistIds, other.artistIds) &&
        _listEquals(categoryIds, other.categoryIds) &&
        _listEquals(blacklistTokens, other.blacklistTokens) &&
        filter.filterEquals(other.filter) &&
        (ignorePage || other.page == page);
  }

  R34SearchRequest duplicate() {
    return R34SearchRequest(
      keywordType: keywordType,
      keyword: keyword,
      filter: filter.duplicate(),
      tagIds: List.of(tagIds),
      artistIds: List.of(artistIds),
      categoryIds: List.of(categoryIds),
      blacklistTokens: List.of(blacklistTokens),
      page: page,
    );
  }

  static bool _listEquals(List<String> a, List<String> b) {
    if (identical(a, b)) {
      return true;
    }
    if (a.length != b.length) {
      return false;
    }
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) {
        return false;
      }
    }
    return true;
  }
}
