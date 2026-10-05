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
  random,
  ;

  static final descriptionMap = LinkedHashMap.of({
    '播放最多': mostViewed,
    '评分最高': topRated,
    '最新发布': newest,
    '时长最久': longest,
    '随机': random,
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
      random: 'pseudo_rand',
    }[this]!;
  }

  String get desc => {
        newest: '最新发布',
        mostViewed: '播放最多',
        topRated: '评分最高',
        longest: '时长最久',
        mostRelevant: '最符合',
        random: '随机',
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
  custom,
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
  /// [custom] 需要外部补充 [FilterSelection.customFromDays] / [customToDays]。
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
      .firstWhere((e) => e.value == this, orElse: () => const MapEntry('自定义', custom))
      .key;
}

/// 一次「筛选条件」的完整描述：排序 + 时长 + 上传时间 + 认证上传者。
///
/// 首页和搜索结果页用的是同一套筛选条件，之前两处各写一份、还只实现了排序，
/// 现在统一到这里，页面只负责渲染和回调。
class FilterSelection {
  HomeSortEnum sortType;
  VideoDuration duration;
  VideoDateAdded dateAdded;

  /// 只显示认证上传者（站点复选框 `flag2`）。
  bool verifiedUploaders;

  /// 自定义时长区间，单位秒，仅 [VideoDuration.custom] 时生效。
  int? customFromSeconds;
  int? customToSeconds;

  /// 自定义上传时间区间，单位天数，仅 [VideoDateAdded.custom] 时生效。
  /// 对应站点 `post_date_from`（旧）/ `post_date_to`（新）。
  int? customFromDays;
  int? customToDays;

  FilterSelection({
    this.sortType = HomeSortEnum.mostViewed,
    this.duration = VideoDuration.all,
    this.dateAdded = VideoDateAdded.all,
    this.verifiedUploaders = false,
    this.customFromSeconds,
    this.customToSeconds,
    this.customFromDays,
    this.customToDays,
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

  /// 上传时间的（from 天数, to 天数），兼容自定义档位。
  ///
  /// 返回 `null` 表示完全不限制。单向快捷档只有 [e0]；自定义才可能双端，
  /// 且任一端留空/非正数则不输出对应参数。
  ({String? from, String? to}) get dateRange {
    if (dateAdded == VideoDateAdded.custom) {
      final from = (customFromDays == null || customFromDays! <= 0)
          ? null
          : '${customFromDays!}';
      final to = (customToDays == null || customToDays! <= 0)
          ? null
          : '${customToDays!}';
      return (from: from, to: to);
    }
    return (from: dateAdded.days, to: null);
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
    final date = dateRange;
    if (date.from != null) {
      params['post_date_from'] = date.from!;
    }
    if (date.to != null) {
      params['post_date_to'] = date.to!;
    }
    if (verifiedUploaders) {
      params['flag2'] = '1';
    }
    return params;
  }

  /// 时长/上传时间/认证上传者是否被限制过。
  bool get hasSecondaryFilter =>
      durationRange != null ||
      dateRange.from != null ||
      dateRange.to != null ||
      verifiedUploaders;

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
    if (dateAdded == VideoDateAdded.custom) {
      final date = dateRange;
      final from = date.from ?? '不限';
      final to = date.to ?? '不限';
      labels.add('$from ~ $to 天前');
    } else if (dateAdded != VideoDateAdded.all) {
      labels.add(dateAdded.desc);
    }
    if (verifiedUploaders) {
      labels.add('认证上传者');
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
      verifiedUploaders: verifiedUploaders,
      customFromSeconds: customFromSeconds,
      customToSeconds: customToSeconds,
      customFromDays: customFromDays,
      customToDays: customToDays,
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
        verifiedUploaders == other.verifiedUploaders &&
        customFromSeconds == other.customFromSeconds &&
        customToSeconds == other.customToSeconds &&
        customFromDays == other.customFromDays &&
        customToDays == other.customToDays;
  }

  FilterSelection copyWith({
    HomeSortEnum? sortType,
    VideoDuration? duration,
    VideoDateAdded? dateAdded,
    bool? verifiedUploaders,
    int? customFromSeconds,
    int? customToSeconds,
    int? customFromDays,
    int? customToDays,
    bool clearCustomDuration = false,
    bool clearCustomDate = false,
  }) {
    return FilterSelection(
      sortType: sortType ?? this.sortType,
      duration: duration ?? this.duration,
      dateAdded: dateAdded ?? this.dateAdded,
      verifiedUploaders: verifiedUploaders ?? this.verifiedUploaders,
      customFromSeconds:
          clearCustomDuration ? null : (customFromSeconds ?? this.customFromSeconds),
      customToSeconds:
          clearCustomDuration ? null : (customToSeconds ?? this.customToSeconds),
      customFromDays:
          clearCustomDate ? null : (customFromDays ?? this.customFromDays),
      customToDays:
          clearCustomDate ? null : (customToDays ?? this.customToDays),
    );
  }

  @override
  String toString() {
    return 'FilterSelection(sort: ${sortType.name}, duration: ${duration.name}, '
        'dateAdded: ${dateAdded.name}, verified: $verifiedUploaders, '
        'custom: $customFromSeconds-$customToSeconds)';
  }
}
