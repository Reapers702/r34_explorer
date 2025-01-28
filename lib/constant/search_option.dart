import 'dart:collection';

class R34SearchOption {
  HomeSortEnum sortType;
  VideoDuration duration;
  VideoDateAdded dateAdded;

  R34SearchOption({
    this.sortType = HomeSortEnum.mostViewed,
    this.duration = VideoDuration.all,
    this.dateAdded = VideoDateAdded.all,
  });
}

enum HomeSortEnum {
  newest,
  mostViewed,
  topRated,
  longest,
  ;

  static final descriptionMap = LinkedHashMap.of({
    '播放最多': mostViewed,
    '评分最高': topRated,
    '最新发布': newest,
    '时长最久': longest,
  });
}

enum VideoDuration {
  all,
  lessThanOneMin,
  oneMinToFiveMin,
  moreThanFiveMin,
}

enum VideoDateAdded {
  all,
  past24H,
  past2Day,
  pastWeek,
  pastMonth,
  past3Month,
  pastYear,
}
