import 'dart:convert';
import 'dart:developer' as dev;

import 'package:r34_video/constant/filter_selection.dart';
import 'package:r34_video/repo/entity/r34_search_request.dart';
import 'package:r34_video/repo/r34_search_repo.dart';

void main() async {
  R34SearchRequest keywordRequest = R34SearchRequest(
    keywordType: SearchKeywordType.keyword,
    keyword: 'tifa',
    page: 2,
    filter: FilterSelection(sortType: HomeSortEnum.mostViewed),
  );

  R34SearchRequest tagRequest = R34SearchRequest(
    keywordType: SearchKeywordType.tag,
    keyword: '5002',
    page: 2,
    filter: FilterSelection(sortType: HomeSortEnum.mostViewed),
  );

  R34SearchRequest categoryRequest = R34SearchRequest(
    keywordType: SearchKeywordType.category,
    keyword: '3d',
    page: 2,
    filter: FilterSelection(
      sortType: HomeSortEnum.mostViewed,
      duration: VideoDuration.more10Min,
      dateAdded: VideoDateAdded.pastMonth,
    ),
  );

  final result = await R34SearchRepo.searchResult(categoryRequest);
  dev.log(jsonEncode(result.toJson()));
  dev.log('keyword/tag requests: $keywordRequest | $tagRequest');
}
