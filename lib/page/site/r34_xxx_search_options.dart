import 'package:flutter/foundation.dart';

/// 排序方式（对应 booru 的 `sort:` 伪标签）。
///
/// 实测代理 `rule34-api.netlify.app` 与 kurosearch 走同一套，
/// 以下四种排序都能返回正确结果。
enum R34XxxSort {
  /// 最新（默认，按 id 倒序）。
  latest,

  /// 评分从高到低。
  score,

  /// 最近更新。
  updated,

  /// 随机。
  random;

  /// 下拉里显示的名字。
  String get label => switch (this) {
        latest => '最新',
        score => '评分',
        updated => '更新',
        random => '随机',
      };
}

/// 评级筛选（对应 booru 的 `rating:` 伪标签）。
///
/// 注意 rule34.xxx 全站没有 safe 内容，`rating:safe` 返回 0 条，
/// 所以默认「全部」。
enum R34XxxRating {
  all,
  safe,
  questionable,
  explicit;

  String get label => switch (this) {
        all => '全部',
        safe => 'safe',
        questionable => 'questionable',
        explicit => 'explicit',
      };

  bool get enabled => this != all;
}

/// 评分的比较符。
enum R34XxxScoreCompare {
  gte,
  lte;

  String get label => switch (this) {
        gte => '≥',
        lte => '≤',
      };
}

/// rule34.xxx 搜索结果的一组「排序 / 筛选」条件。
///
/// 这些条件最终都翻译成 booru 伪标签拼进 `tags` 参数：
/// * 排序 -> `sort:score:desc` 等；
/// * 评分下限 -> `score:>=1000`（或 `<=`）；
/// * 评级 -> `rating:explicit` 等。
///
/// 与 tag 一样，它们只在用户点「搜索」按钮时才生效（进待提交区，
/// 不自动发请求）。
@immutable
class R34XxxSearchOptions {
  const R34XxxSearchOptions({
    this.sort = R34XxxSort.latest,
    this.minScore,
    this.scoreCompare = R34XxxScoreCompare.gte,
    this.rating = R34XxxRating.all,
  });

  final R34XxxSort sort;

  /// 评分阈值；null 表示不过滤。
  final int? minScore;

  /// 评分比较符（仅当 [minScore] 非空时有效）。
  final R34XxxScoreCompare scoreCompare;

  final R34XxxRating rating;

  /// 是否就是出厂默认（无任何筛选）。
  bool get isDefault =>
      sort == R34XxxSort.latest &&
      minScore == null &&
      rating == R34XxxRating.all;

  /// 翻译成伪标签（空格分隔的 tag 片段），会拼进搜索串。
  List<String> toTagClauses() {
    final clauses = <String>[
      switch (sort) {
        R34XxxSort.latest => 'sort:id:desc',
        R34XxxSort.score => 'sort:score:desc',
        R34XxxSort.updated => 'sort:updated_at:desc',
        R34XxxSort.random => 'sort:random',
      },
    ];
    if (minScore != null) {
      final op = scoreCompare == R34XxxScoreCompare.gte ? '>=' : '<=';
      clauses.add('score:$op$minScore');
    }
    if (rating.enabled) {
      clauses.add('rating:${rating.name}');
    }
    return clauses;
  }

  /// 把已有 tag 串与筛选条件拼成完整搜索串。
  ///
  /// 一个条件都没有时返回空串——接口侧 `getPosts` 会自己补默认的
  /// `sort:id:desc`，这里保持空是为了让页面能判断「没有任何条件」
  ///（空态提示依赖它）。
  String toTagQuery(String baseTags) {
    final trimmed = baseTags.trim();
    if (trimmed.isEmpty && isDefault) {
      return '';
    }
    return [trimmed, ...toTagClauses()]
        .where((s) => s.isNotEmpty)
        .join(' ');
  }

  /// 按钮上的一句话状态，如「评分 ≥ 1000」「最新」「评分 ≥ 1000 explicit」。
  String describe() {
    if (isDefault) {
      return '最新投稿';
    }
    final parts = <String>[sort.label];
    if (minScore != null) {
      parts.add('${scoreCompare.label} $minScore');
    }
    if (rating.enabled) {
      parts.add(rating.label);
    }
    return parts.join(' ');
  }

  R34XxxSearchOptions copyWith({
    R34XxxSort? sort,
    int? minScore,
    R34XxxScoreCompare? scoreCompare,
    R34XxxRating? rating,
  }) {
    return R34XxxSearchOptions(
      sort: sort ?? this.sort,
      minScore: minScore ?? this.minScore,
      scoreCompare: scoreCompare ?? this.scoreCompare,
      rating: rating ?? this.rating,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is R34XxxSearchOptions &&
        other.sort == sort &&
        other.minScore == minScore &&
        other.scoreCompare == scoreCompare &&
        other.rating == rating;
  }

  @override
  int get hashCode => Object.hash(sort, minScore, scoreCompare, rating);

  @override
  String toString() => 'R34XxxSearchOptions(${describe()})';
}
