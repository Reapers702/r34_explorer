import 'dart:convert';

import 'package:r34_video/repo/entity/r34_page.dart';
import 'package:r34_video/repo/entity/r34_xxx_post.dart';
import 'package:r34_video/util/log_util.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 收藏/历史内容的类型。
enum SavedType {
  /// rule34.xxx 图片站的一篇投稿。
  xxx,

  /// rule34video.com 的一个视频。
  video,
}

/// 一条可被收藏/记录进历史的跨站内容。
///
/// 只持久化「重新打开详情页」所需的够用字段 + 一份原实体数据（[payload]），
/// 展示用 [title]/[thumbUrl]，跳转时用 [toPost] / [toVideo] 还原详情页参数。
class SavedContent {
  final SavedType type;

  /// 站内唯一键：图片用 `xxx_<id>`，视频用 [detailUrl]。
  final String keyId;

  final String title;
  final String thumbUrl;

  /// 原实体的原始字段，用于还原 [R34XxxPost] / [R34Video]。
  final Map<String, dynamic> payload;

  /// Unix 毫秒，收藏/入库时间，用于排序。
  final int savedAt;

  SavedContent({
    required this.type,
    required this.keyId,
    required this.title,
    required this.thumbUrl,
    required this.payload,
    required this.savedAt,
  });

  factory SavedContent.fromPost(R34XxxPost post) {
    return SavedContent(
      type: SavedType.xxx,
      keyId: 'xxx_${post.id}',
      title: 'post #${post.id}',
      thumbUrl: post.sampleUrl.isNotEmpty ? post.sampleUrl : post.previewUrl,
      payload: {
        'id': post.id,
        'preview_url': post.previewUrl,
        'sample_url': post.sampleUrl,
        'file_url': post.fileUrl,
        'width': post.width,
        'height': post.height,
        'sample_width': post.sampleWidth,
        'sample_height': post.sampleHeight,
        'rating': post.rating,
        'score': post.score,
        'owner': post.owner,
        'tags': post.tagsRaw,
        'change': post.change,
      },
      savedAt: DateTime.now().millisecondsSinceEpoch,
    );
  }

  factory SavedContent.fromVideo(R34Video video) {
    return SavedContent(
      type: SavedType.video,
      keyId: video.detailUrl,
      title: video.title,
      thumbUrl: video.thumbImageUrl,
      payload: video.toJson(),
      savedAt: DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// 还原图片详情页参数；类型不匹配时返回 null。
  R34XxxPost? toPost() {
    if (type != SavedType.xxx) {
      return null;
    }
    return R34XxxPost.fromJson(payload);
  }

  /// 还原视频详情页参数；类型不匹配时返回 null。
  R34Video? toVideo() {
    if (type != SavedType.video) {
      return null;
    }
    return R34Video(
      title: (payload['title'] ?? '') as String,
      detailUrl: (payload['detailUrl'] ?? '') as String,
      videoPreviewUrl: (payload['videoPreviewUrl'] ?? '') as String,
      thumbImageUrl: (payload['thumbImageUrl'] ?? '') as String,
      videoDuration: (payload['videoDuration'] ?? '') as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'keyId': keyId,
        'title': title,
        'thumbUrl': thumbUrl,
        'payload': payload,
        'savedAt': savedAt,
      };

  factory SavedContent.fromJson(Map<String, dynamic> json) {
    return SavedContent(
      type: SavedType.values.byName(json['type'] ?? SavedType.xxx.name),
      keyId: (json['keyId'] ?? '') as String,
      title: (json['title'] ?? '') as String,
      thumbUrl: (json['thumbUrl'] ?? '') as String,
      payload: (json['payload'] as Map?)?.cast<String, dynamic>() ?? const {},
      savedAt: (json['savedAt'] ?? 0) as int,
    );
  }
}

/// 本地收藏与浏览历史仓库（仅本机，不依赖登录）。
///
/// 持久化在 SharedPreferences，模式与 [CookieStore] / [LocalUserRepo] 一致：
/// 内存缓存 + 磁盘 JSON。收藏按 [SavedContent.keyId] 去重；历史天然按时间
/// 倒序存放，重复浏览时移到最新。
class LocalContentRepo {
  LocalContentRepo._();

  static const String _favKey = 'local_content_favorites';
  static const String _histKey = 'local_content_history';

  /// 历史最多保留的条数，超出丢弃最旧的。
  static const int _maxHistory = 200;

  static final Map<String, SavedContent> _favorites = {};
  static final List<SavedContent> _history = [];
  static bool _loaded = false;

  static Future<void> _ensureLoaded() async {
    if (_loaded) {
      return;
    }
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();

      final favRaw = prefs.getString(_favKey);
      if (favRaw != null && favRaw.isNotEmpty) {
        for (final item in (jsonDecode(favRaw) as List)) {
          final saved = SavedContent.fromJson((item as Map).cast());
          _favorites[saved.keyId] = saved;
        }
      }

      final histRaw = prefs.getString(_histKey);
      if (histRaw != null && histRaw.isNotEmpty) {
        final list = (jsonDecode(histRaw) as List)
            .map((e) => SavedContent.fromJson((e as Map).cast()))
            .toList();
        _history
          ..clear()
          ..addAll(list);
      }
    } catch (e, st) {
      LogUtil.error('load local content failed: $e\n$st');
    }
  }

  static Future<void> _persistFavorites() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _favKey,
        jsonEncode(_favorites.values.map((e) => e.toJson()).toList()),
      );
    } catch (e, st) {
      LogUtil.error('persist favorites failed: $e\n$st');
    }
  }

  static Future<void> _persistHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _histKey,
        jsonEncode(_history.map((e) => e.toJson()).toList()),
      );
    } catch (e, st) {
      LogUtil.error('persist history failed: $e\n$st');
    }
  }

  // ---- 收藏 ----

  /// 收藏列表，新的在前。
  static Future<List<SavedContent>> favorites() async {
    await _ensureLoaded();
    final list = _favorites.values.toList()
      ..sort((a, b) => b.savedAt.compareTo(a.savedAt));
    return list;
  }

  static Future<bool> isFavorite(String keyId) async {
    await _ensureLoaded();
    return _favorites.containsKey(keyId);
  }

  /// 收藏/取消收藏，返回操作后的状态（true=已收藏）。
  static Future<bool> toggleFavorite(SavedContent item) async {
    await _ensureLoaded();
    if (_favorites.containsKey(item.keyId)) {
      _favorites.remove(item.keyId);
      await _persistFavorites();
      return false;
    }
    _favorites[item.keyId] = item;
    await _persistFavorites();
    return true;
  }

  static Future<void> removeFavorite(String keyId) async {
    await _ensureLoaded();
    if (_favorites.remove(keyId) != null) {
      await _persistFavorites();
    }
  }

  static Future<void> clearFavorites() async {
    await _ensureLoaded();
    _favorites.clear();
    await _persistFavorites();
  }

  // ---- 历史 ----

  /// 浏览历史，最新的在前。
  static Future<List<SavedContent>> history() async {
    await _ensureLoaded();
    return List.unmodifiable(_history);
  }

  /// 记一条浏览历史：同内容移到最前，超出上限丢最旧。
  static Future<void> pushHistory(SavedContent item) async {
    await _ensureLoaded();
    _history.removeWhere((e) => e.keyId == item.keyId);
    _history.insert(0, item);
    if (_history.length > _maxHistory) {
      _history.removeRange(_maxHistory, _history.length);
    }
    await _persistHistory();
  }

  static Future<void> removeHistory(String keyId) async {
    await _ensureLoaded();
    final before = _history.length;
    _history.removeWhere((e) => e.keyId == keyId);
    if (_history.length != before) {
      await _persistHistory();
    }
  }

  static Future<void> clearHistory() async {
    await _ensureLoaded();
    _history.clear();
    await _persistHistory();
  }
}