/// rule34.xxx 的一篇投稿。
///
/// 字段直接对应公开 JSON API（见 [R34XxxRepo]）的返回，不做重命名，
/// 省得以后对不上。
class R34XxxPost {
  final int id;
  final String previewUrl;
  final String sampleUrl;
  final String fileUrl;

  final int width;
  final int height;
  final int sampleWidth;
  final int sampleHeight;

  /// `explicit` / `questionable` / `safe`
  final String rating;

  final int score;
  final String owner;

  /// 空格分隔的 tag 串，用 [tags] 拿列表。
  final String tagsRaw;

  /// Unix 秒。
  final int change;

  const R34XxxPost({
    required this.id,
    required this.previewUrl,
    required this.sampleUrl,
    required this.fileUrl,
    required this.width,
    required this.height,
    required this.rating,
    required this.score,
    required this.owner,
    required this.tagsRaw,
    required this.change,
    this.sampleWidth = 0,
    this.sampleHeight = 0,
  });

  List<String> get tags => tagsRaw
      .split(' ')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();

  double get aspectRatio {
    if (width <= 0 || height <= 0) {
      return 1;
    }
    return width / height;
  }

  String get ratingLabel => {
        'explicit': 'Explicit',
        'questionable': 'Questionable',
        'safe': 'Safe',
      }[rating] ??
      rating;

  DateTime? get updatedAt {
    if (change <= 0) {
      return null;
    }
    return DateTime.fromMillisecondsSinceEpoch(change * 1000);
  }

  static int _asInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse('${value ?? ''}') ?? 0;
  }

  static String _asString(dynamic value) => '${value ?? ''}';

  factory R34XxxPost.fromJson(Map<String, dynamic> json) {
    return R34XxxPost(
      id: _asInt(json['id']),
      previewUrl: _asString(json['preview_url']),
      sampleUrl: _asString(json['sample_url']),
      fileUrl: _asString(json['file_url']),
      width: _asInt(json['width']),
      height: _asInt(json['height']),
      sampleWidth: _asInt(json['sample_width']),
      sampleHeight: _asInt(json['sample_height']),
      rating: _asString(json['rating']),
      score: _asInt(json['score']),
      owner: _asString(json['owner']),
      tagsRaw: _asString(json['tags']),
      change: _asInt(json['change']),
    );
  }
}

/// 一页投稿 + 总数。
class R34XxxPage {
  final List<R34XxxPost> posts;

  /// 命中的总数（来自 `/count`），拿不到就是 -1。
  final int total;

  const R34XxxPage({required this.posts, this.total = -1});

  bool get hasTotal => total >= 0;

  int totalPages(int perPage) {
    if (!hasTotal || perPage <= 0) {
      return 0;
    }
    return (total / perPage).ceil();
  }
}
