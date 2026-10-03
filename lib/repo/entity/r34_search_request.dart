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

  int page;

  R34SearchRequest({
    required this.keywordType,
    required this.keyword,
    FilterSelection? filter,
    this.page = 1,
  }) : filter = filter ?? FilterSelection(sortType: HomeSortEnum.mostRelevant);

  HomeSortEnum get sortType => filter.sortType;

  set sortType(HomeSortEnum value) => filter.sortType = value;

  /// 供 UI 展示的搜索条件摘要。
  Map<String, dynamic> toJson() {
    return {
      'keywordType': keywordType.name,
      'keyword': keyword,
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
        filter.filterEquals(other.filter) &&
        (ignorePage || other.page == page);
  }

  R34SearchRequest duplicate() {
    return R34SearchRequest(
      keywordType: keywordType,
      keyword: keyword,
      filter: filter.duplicate(),
      page: page,
    );
  }
}
