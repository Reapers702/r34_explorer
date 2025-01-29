import 'dart:collection';

class R34SearchOption {
  HomeSortEnum sortType;
  VideoDuration duration;
  VideoDateAdded dateAdded;

  int page;

  R34SearchOption({
    this.sortType = HomeSortEnum.mostViewed,
    this.duration = VideoDuration.all,
    this.dateAdded = VideoDateAdded.all,
    this.page = 1,
  });

  bool equals(R34SearchOption? other) {
    if (other == null) {
      return false;
    }
    return sortType == other.sortType &&
        duration == other.duration &&
        dateAdded == other.dateAdded;
  }

  R34SearchOption duplicate() {
    return R34SearchOption(
      sortType: sortType,
      duration: duration,
      dateAdded: dateAdded,
    );
  }

  String get officialPage {
    final re = page.toString();
    return re.padLeft(2, '0');
  }

  @override
  String toString() {
    return 'R34SearchOption(sortType: $sortType, duration: $duration, dateAdded: $dateAdded)';
  }
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

  String get officialTag {
    return {
      newest: 'post_date',
      mostViewed: 'video_viewed',
      topRated: 'rating',
      longest: 'duration',
    }[this]!;
  }
}

enum VideoDuration {
  all,
  more1Min,
  more5Min,
  more10Min,
  more20Min,
  more30Min,
  more60Min,
  less10Min,
  less20Min,
  ;

  static final descriptionMap = LinkedHashMap.of({
    '全部': all,
    '1分以上': more1Min,
    '5分以上': more5Min,
    '10分以上': more10Min,
    '20分以上': more20Min,
    '30分以上': more30Min,
    '1小时以上': more60Min,
    '10分以下': less10Min,
    '20分以下': less20Min,
  });
}

enum VideoDateAdded {
  all,
  past24H,
  past2Day,
  pastWeek,
  pastMonth,
  past3Month,
  pastYear,
  ;

  static final descriptionMap = LinkedHashMap.of({
    '全部': all,
    '最近24小时': past24H,
    '最近2天': past2Day,
    '最近1周': pastWeek,
    '最近1个月': pastMonth,
    '最近3个月': past3Month,
    '最近1年': pastYear,
  });
}
