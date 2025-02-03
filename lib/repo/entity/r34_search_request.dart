import 'package:r34_video/constant/search_option.dart';

enum SearchKeywordType {
  keyword,
  tag,
  artist,
  category,
}

class R34SearchRequest {
  final SearchKeywordType keywordType;
  final String keyword;

  HomeSortEnum sortType;
  VideoDuration duration;
  int page;

  R34SearchRequest({
    required this.keywordType,
    required this.keyword,
    required this.sortType,
    this.duration = VideoDuration.all,
    required this.page,
  });

  Map<String, dynamic> toJson() {
    return {
      'keywordType': keywordType.name,
      'keyword': keyword,
      'page': page,
      'sort': sortType.name,
      'duration': duration.name,
    };
  }

  bool equals(R34SearchRequest? other, {bool ignorePage = false}) {
    if (other == null) {
      return false;
    }
    return keywordType == other.keywordType &&
        keyword == other.keyword &&
        sortType == other.sortType &&
        duration == other.duration &&
        page == other.page &&
        (ignorePage || other.page == page);
  }

  R34SearchRequest duplicate() {
    return R34SearchRequest(
      keywordType: keywordType,
      keyword: keyword,
      sortType: sortType,
      duration: duration,
      page: page,
    );
  }
}
