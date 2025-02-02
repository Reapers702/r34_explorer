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

  final HomeSortEnum sortType;
  final VideoDuration duration;

  final int page;

  R34SearchRequest({
    required this.keywordType,
    required this.keyword,
    required this.sortType,
    this.duration = VideoDuration.all,
    required this.page,
  });
}
