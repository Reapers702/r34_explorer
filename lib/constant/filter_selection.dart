import 'dart:collection';

/// 排序方式。
///
/// 站点本身支持的 `sort_by` 取值，`officialTag` 就是请求里真实要传的值。
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

  static final descriptionMapWithSearch =
      LinkedHashMap.of({'最符合': mostRelevant})..addAll(descriptionMap);

  String get officialTag {
    return {
      newest: 'post_date',
      mostViewed: 'video_viewed',
      topRated: 'rating',
      longest: 'duration',
      mostRelevant: '',
    }[this]!;
  }

  String get desc => {
        newest: '最新发布',
        mostViewed: '播放最多',
        topRated: '评分最高',
        longest: '时长最久',
        mostRelevant: '最符合',
      }[this]!;
}

/// 视频时长筛选。
///
/// 站点搜索框是「分钟/秒」双输入，这里沿用站点的预设档位 + 自定义区间。
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
  custom,
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

  /// 秒。`null` 表示该侧不限制。`custom` 需要外部补充自定义区间。
  ({String? from, String? to})? get range {
    return {
      more1Min: (from: '60', to: null),
      more5Min: (from: '300', to: null),
      more10Min: (from: '600', to: null),
      more20Min: (from: '1200', to: null),
      more30Min: (from: '1800', to: null),
      more60Min: (from: '3600', to: null),
      less10Min: (from: '1', to: '600'),
      less20Min: (from: '1', to: '1200'),
    }[this];
  }

  String get desc => descriptionMap.entries
      .firstWhere((e) => e.value == this, orElse: () => const MapEntry('自定义', custom))
      .key;
}

/// 上传时间筛选，对应站点的 `post_date_from`。
///
/// 站点 UI 上给的是 24 小时 / 2 天 / 1 周 / … ，服务端把这个值直接当**天数**用
/// （`post_date_from=1` 就是最近 24 小时），所以这里存天数。
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

  /// 传给服务端的天数，`null` 表示不限制。
  String? get days {
    return {
      past24H: '1',
      past2Day: '2',
      pastWeek: '7',
      pastMonth: '30',
      past3Month: '90',
      pastYear: '365',
    }[this];
  }

  String get desc => descriptionMap.entries
      .firstWhere((e) => e.value == this)
      .key;
}

/// 一次「筛选条件」的完整描述：排序 + 时长 + 上传时间。
///
/// 首页和搜索结果页用的是同一套筛选条件，之前两处各写一份、还只实现了排序，
/// 现在统一到这里，页面只负责渲染和回调。
class FilterSelection {
  HomeSortEnum sortType;
  VideoDuration duration;
  VideoDateAdded dateAdded;

  /// 自定义时长区间，单位秒，仅 [VideoDuration.custom] 时生效。
  int? customFromSeconds;
  int? customToSeconds;

  FilterSelection({
    this.sortType = HomeSortEnum.mostViewed,
    this.duration = VideoDuration.all,
    this.dateAdded = VideoDateAdded.all,
    this.customFromSeconds,
    this.customToSeconds,
  });

  /// 时长区间的秒数，兼容自定义档位。
  ({String? from, String? to})? get durationRange {
    if (duration == VideoDuration.custom) {
      final from = (customFromSeconds == null || customFromSeconds! <= 0)
          ? null
          : '${customFromSeconds!}';
      final to = (customToSeconds == null || customToSeconds! <= 0)
          ? null
          : '${customToSeconds!}';
      if (from == null && to == null) {
        return null;
      }
      return (from: from, to: to);
    }
    return duration.range;
  }

  /// 服务端可识别的筛选查询参数。
  ///
  /// 这几个参数站点是认的（首页一直是靠 cookie 传同样的键，搜索接口用 query 也一样生效），
  /// 相比 cookie 的好处是不会污染后续所有请求。
  Map<String, String> get queryParams {
    final params = <String, String>{};
    final range = durationRange;
    if (range?.from != null) {
      params['duration_from'] = range!.from!;
    }
    if (range?.to != null) {
      params['duration_to'] = range!.to!;
    }
    if (dateAdded.days != null) {
      params['post_date_from'] = dateAdded.days!;
    }
    return params;
  }

  /// 时长/上传时间是否被限制过。
  bool get hasSecondaryFilter =>
      durationRange != null || dateAdded != VideoDateAdded.all;

  /// 是否有自定义时长区间。
  bool get isCustomDuration =>
      duration == VideoDuration.custom && durationRange != null;

  /// 用于展示的「筛选中」标签，例如 `["1小时以上", "最近1周"]`。
  List<String> get activeLabels {
    final labels = <String>[];
    if (isCustomDuration) {
      final range = durationRange!;
      final from = range.from == null ? '0' : range.from!;
      final to = range.to == null ? '不限' : range.to!;
      labels.add('${_humanSeconds(from)} ~ ${_humanSeconds(to)}');
    } else if (duration != VideoDuration.all) {
      labels.add(duration.desc);
    }
    if (dateAdded != VideoDateAdded.all) {
      labels.add(dateAdded.desc);
    }
    return labels;
  }

  static String _humanSeconds(String seconds) {
    final value = int.tryParse(seconds);
    if (value == null) {
      return seconds;
    }
    if (value >= 3600) {
      final hours = value ~/ 3600;
      final minutes = (value % 3600) ~/ 60;
      return minutes == 0 ? '$hours小时' : '$hours小时$minutes分';
    }
    if (value >= 60) {
      return '${value ~/ 60}分';
    }
    return '$value秒';
  }

  FilterSelection duplicate() {
    return FilterSelection(
      sortType: sortType,
      duration: duration,
      dateAdded: dateAdded,
      customFromSeconds: customFromSeconds,
      customToSeconds: customToSeconds,
    );
  }

  /// 是否是同一组筛选条件（忽略翻页）。
  bool filterEquals(FilterSelection? other) {
    if (other == null) {
      return false;
    }
    return sortType == other.sortType &&
        duration == other.duration &&
        dateAdded == other.dateAdded &&
        customFromSeconds == other.customFromSeconds &&
        customToSeconds == other.customToSeconds;
  }

  FilterSelection copyWith({
    HomeSortEnum? sortType,
    VideoDuration? duration,
    VideoDateAdded? dateAdded,
    int? customFromSeconds,
    int? customToSeconds,
    bool clearCustomDuration = false,
  }) {
    return FilterSelection(
      sortType: sortType ?? this.sortType,
      duration: duration ?? this.duration,
      dateAdded: dateAdded ?? this.dateAdded,
      customFromSeconds:
          clearCustomDuration ? null : (customFromSeconds ?? this.customFromSeconds),
      customToSeconds:
          clearCustomDuration ? null : (customToSeconds ?? this.customToSeconds),
    );
  }

  @override
  String toString() {
    return 'FilterSelection(sort: ${sortType.name}, duration: ${duration.name}, '
        'dateAdded: ${dateAdded.name}, custom: $customFromSeconds-$customToSeconds)';
  }
}
