import 'dart:collection';

class R34HomeFilterOption {
  HomeSortEnum sortType;
  VideoDuration duration;
  VideoDateAdded dateAdded;

  int page;

  R34HomeFilterOption({
    this.sortType = HomeSortEnum.mostViewed,
    this.duration = VideoDuration.all,
    this.dateAdded = VideoDateAdded.all,
    this.page = 1,
  });

  bool equals(R34HomeFilterOption? other) {
    if (other == null) {
      return false;
    }
    return sortType == other.sortType &&
        duration == other.duration &&
        dateAdded == other.dateAdded &&
        page == other.page;
  }

  bool filterEquals(R34HomeFilterOption? other) {
    if (other == null) {
      return false;
    }
    return sortType == other.sortType &&
        duration == other.duration &&
        dateAdded == other.dateAdded;
  }

  R34HomeFilterOption duplicate() {
    return R34HomeFilterOption(
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
  mostRelevant,
  ;

  static final descriptionMap = LinkedHashMap.of({
    '播放最多': mostViewed,
    '评分最高': topRated,
    '最新发布': newest,
    '时长最久': longest,
  });

  static final descriptionMapWithSearch = LinkedHashMap.of(descriptionMap)
    ..addAll({'最符合的': mostRelevant});

  String get officialTag {
    return {
      newest: 'post_date',
      mostViewed: 'video_viewed',
      topRated: 'rating',
      longest: 'duration',
      mostRelevant: '',
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

  String get cookieValue {
    final cookieMap = <VideoDuration, Map<String, String>>{
          more1Min: {'duration_from': '60'},
          more5Min: {'duration_from': '300'},
          more10Min: {'duration_from': '600'},
          more20Min: {'duration_from': '1200'},
          more30Min: {'duration_from': '1800'},
          more60Min: {'duration_from': '3600'},
          less10Min: {'duration_from': '1', 'duration_to': '600'},
          less20Min: {'duration_from': '1', 'duration_to': '1200'},
        }[this] ??
        {};
    if (cookieMap.isEmpty) {
      return '';
    }
    return '${cookieMap.entries.map((e) => '${e.key}=${e.value}').join('; ')}; ';
  }
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

  String get cookieValue {
    final cookieMap = <VideoDateAdded, Map<String, String>>{
          past24H: {'post_date_from': '1'},
          past2Day: {'post_date_from': '2'},
          pastWeek: {'post_date_from': '3'},
          pastMonth: {'post_date_from': '4'},
          past3Month: {'post_date_from': '5'},
          pastYear: {'post_date_from': '6'},
        }[this] ??
        {};
    if (cookieMap.isEmpty) {
      return '';
    }
    return '${cookieMap.entries.map((e) => '${e.key}=${e.value}').join('; ')}; ';
  }
}
