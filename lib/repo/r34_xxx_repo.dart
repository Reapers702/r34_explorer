import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:r34_video/repo/entity/r34_xxx_post.dart';
import 'package:r34_video/util/http_trace_util.dart';
import 'package:r34_video/util/log_util.dart';

/// rule34.xxx 数据源。
///
/// **重要说明（为什么不走官方 API）**
///
/// rule34.xxx 官方 API（`api.rule34.xxx/index.php?page=dapi...`）现在强制要求
/// `user_id` + `api_key`，一人一 key、不可共用，没有凭据直接返回
/// `Missing authentication`。
///
/// 而 [kurozenzen/kurosearch] 用的是一条**公开代理**：`rule34-api.netlify.app`，
/// 无需鉴权即可 `/posts`、`/count`。本 App 走的就是这条（r34.app 的做法类似）。
///
/// 代价：这是第三方托管，可能限流或下线。所以：
/// * [_baseUrl] 单独抽出来，将来你拿到官方 key，改成官方 host 即可；
/// * 所有失败都返回空列表 + 明确日志，不会让页面崩。
///
/// [kurozenzen/kurosearch]: https://github.com/kurozenzen/kurosearch
class R34XxxRepo {
  const R34XxxRepo._();

  /// 公开代理（无鉴权）。
  static const String _baseUrl = 'https://rule34-api.netlify.app';

  /// 单次请求上限。
  static const int maxLimit = 100;

  /// 页面默认每页条数。
  static const int defaultLimit = 30;

  /// 拉一页投稿。
  ///
  /// [tags] 用空格分隔，支持 booru 语法（`cat solo`、`-male`、`sort:score:desc` 等），
  /// 和站点网页上的 tag 搜索一致。
  static Future<R34XxxPage> getPosts({
    String tags = '',
    int page = 0,
    int limit = defaultLimit,
    bool withTotal = true,
  }) async {
    final safeLimit = limit.clamp(1, maxLimit);
    final uri = Uri.parse('$_baseUrl/posts').replace(queryParameters: {
      'limit': '$safeLimit',
      'pid': '${page < 0 ? 0 : page}',
      'tags': tags.trim().isEmpty ? 'sort:id:desc' : tags.trim(),
    });

    try {
      final res = await http
          .get(uri, headers: const {'accept': 'application/json'})
          .timeout(const Duration(seconds: 20));

      if (res.statusCode != 200) {
        HttpTraceUtil.handleHttpError(res.statusCode);
        return const R34XxxPage(posts: []);
      }

      final dynamic decoded = jsonDecode(res.body);
      if (decoded is! List) {
        LogUtil.warn('r34xxx: unexpected /posts payload');
        return const R34XxxPage(posts: []);
      }

      final posts = decoded
          .whereType<Map<String, dynamic>>()
          .map(R34XxxPost.fromJson)
          .where((p) => p.fileUrl.isNotEmpty)
          .toList();

      final total = withTotal ? await getCount(tags) : -1;
      return R34XxxPage(posts: posts, total: total);
    } catch (e, st) {
      HttpTraceUtil.handleConnectionError(e, st: st);
      return const R34XxxPage(posts: []);
    }
  }

  /// 命中总数。失败返回 -1。
  static Future<int> getCount(String tags) async {
    final uri = Uri.parse('$_baseUrl/count').replace(queryParameters: {
      'tags': tags.trim().isEmpty ? 'sort:id:desc' : tags.trim(),
    });

    try {
      final res = await http
          .get(uri, headers: const {'accept': 'application/xml'})
          .timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) {
        return -1;
      }
      // 返回形如 <posts count="454110" offset="0"></posts>
      final match = RegExp(r'count="(\d+)"').firstMatch(res.body);
      return int.tryParse(match?.group(1) ?? '') ?? -1;
    } catch (e) {
      LogUtil.warn('r34xxx count failed: $e');
      return -1;
    }
  }

  /// tag 联想（站点自己用的那套）。
  ///
  /// 走官方 `autocomplete.php` —— 它**不需要鉴权**（跟 `/index.php?page=dapi` 不同）。
  /// 返回形如：
  /// ```json
  /// [{"label":"ada_wong (23076)","value":"ada_wong"}]
  /// ```
  /// [label] 带使用量用于展示，[value] 才是真正的 tag。
  ///
  /// 注意 booru 规范：**tag 内部用下划线**，空格是 tag 之间的分隔符。
  /// 所以 `q=ada w` 不会命中，`q=ada_w` 才行 —— 输入时要把空格换成下划线。
  static Future<List<R34XxxTagSuggestion>> autocomplete(
    String query, {
    int limit = 10,
  }) async {
    final keyword = normalizeTagQuery(query);
    if (keyword.isEmpty) {
      return const [];
    }

    final uri = Uri.https('api.rule34.xxx', '/autocomplete.php', {'q': keyword});

    try {
      final res = await http
          .get(uri, headers: const {'accept': 'application/json'})
          .timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) {
        return const [];
      }

      final dynamic decoded = jsonDecode(res.body);
      if (decoded is! List) {
        return const [];
      }

      final result = <R34XxxTagSuggestion>[];
      for (final item in decoded) {
        if (item is! Map) {
          continue;
        }
        final value = '${item['value'] ?? ''}'.trim();
        if (value.isEmpty) {
          continue;
        }
        result.add(R34XxxTagSuggestion(
          value: value,
          label: '${item['label'] ?? value}'.trim(),
        ));
        if (result.length >= limit) {
          break;
        }
      }
      return result;
    } catch (e) {
      // 联想失败不该打扰用户，静默返回空即可。
      LogUtil.warn('r34xxx autocomplete failed: $e');
      return const [];
    }
  }

  /// 把用户输入规整成合法 tag：空格/连字符换成下划线，去掉多余字符。
  ///
  /// 这样用户直接打 "ada wong" 也能命中站点上的 `ada_wong`。
  static String normalizeTagQuery(String raw) {
    return raw
        .trim()
        .replaceAll(RegExp(r'[\s\-]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
  }

  /// 帖子评论。
  ///
  /// 代理的这个端点基本只返回空数组（站点评论本来就少），保留是为了
  /// 将来接官方 API 时不用改调用方。
  static Future<List<R34XxxComment>> getComments(int postId) async {
    final uri = Uri.parse('$_baseUrl/comments')
        .replace(queryParameters: {'post_id': '$postId'});

    try {
      final res = await http
          .get(uri, headers: const {'accept': 'application/xml'})
          .timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) {
        return const [];
      }
      return _parseComments(res.body);
    } catch (e, st) {
      HttpTraceUtil.handleConnectionError(e, st: st);
      return const [];
    }
  }

  /// 解析 `<comments type="array"><comment ...><body>..</body></comment>...`。
  static List<R34XxxComment> _parseComments(String xml) {
    final comments = <R34XxxComment>[];
    for (final match in RegExp(r'<comment\b[^>]*>(.*?)</comment>',
            dotAll: true)
        .allMatches(xml)) {
      final block = match.group(1) ?? '';
      String pick(String tag) {
        final m = RegExp('<$tag>(.*?)</$tag>', dotAll: true).firstMatch(block);
        return (m?.group(1) ?? '')
            .replaceAll('&lt;', '<')
            .replaceAll('&gt;', '>')
            .replaceAll('&quot;', '"')
            .replaceAll('&amp;', '&')
            .trim();
      }

      final body = pick('body');
      if (body.isEmpty) {
        continue;
      }
      comments.add(R34XxxComment(
        author: pick('creator'),
        body: body,
        createdAt: pick('created_at'),
      ));
    }
    return comments;
  }
}

class R34XxxComment {
  final String author;
  final String body;
  final String createdAt;

  const R34XxxComment({
    required this.author,
    required this.body,
    this.createdAt = '',
  });
}

/// tag 联想的一条结果。
class R34XxxTagSuggestion {
  /// 真正的 tag（可直接用于搜索），例如 `ada_wong`。
  final String value;

  /// 展示用文案，通常带使用量，例如 `ada_wong (23076)`。
  final String label;

  const R34XxxTagSuggestion({required this.value, required this.label});

  /// 站点展示时会把下划线换成空格，这里保持一致。
  String get displayName => value.replaceAll('_', ' ');

  @override
  String toString() => 'R34XxxTagSuggestion($value / $label)';
}
