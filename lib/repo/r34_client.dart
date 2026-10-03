import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:r34_video/constant/r34_const.dart';
import 'package:r34_video/repo/cookie_store.dart';
import 'package:r34_video/util/log_util.dart';

/// 统一网络入口。
///
/// 两个职责：
/// 1. **请求前**注入 [CookieStore] 里的 cookie（替换原来写死在 header 里的那一份）；
/// 2. **响应后**把服务端的 `Set-Cookie` 收回 [CookieStore]。
///
/// 第 2 点很关键：站点的 Cloudflare/DDG 风控是靠 `Set-Cookie` 下发 `__ddg*` 的，
/// 之前不回写，就等于每次都拿旧 cookie 去撞墙。
class R34Client {
  R34Client({http.Client? client, Duration? timeout})
      : _client = client ?? http.Client(),
        _timeout = timeout ?? const Duration(seconds: 15);

  /// 全局共享实例：cookie 状态只有一份，所有 repo 都走它。
  static final R34Client instance = R34Client();

  final http.Client _client;
  final Duration _timeout;

  /// 当前可用请求头（已带 cookie）。
  Map<String, String> get headers => R34Headers.build();

  Future<http.Response> get(
    Uri uri, {
    Map<String, String>? headers,
    bool allowRedirect = true,
  }) async {
    final request = http.Request('GET', uri);
    request.headers.addAll(_mergeHeaders(headers));
    request.followRedirects = allowRedirect;
    return _send(request);
  }

  Future<http.Response> post(
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    final request = http.Request('POST', uri);
    request.headers.addAll(_mergeHeaders(headers));
    if (body is Map) {
      request.bodyFields = body.map(
        (key, value) => MapEntry(key.toString(), value.toString()),
      );
    } else if (body is String) {
      request.body = body;
    }
    return _send(request);
  }

  /// 直接发一个自定义 [http.Request]（例如需要 `followRedirects = false`）。
  Future<http.Response> send(http.Request request) async {
    final extra = request.headers.isEmpty
        ? null
        : Map<String, String>.of(request.headers);
    request.headers
      ..clear()
      ..addAll(_mergeHeaders(extra));
    return _send(request);
  }

  Map<String, String> _mergeHeaders(Map<String, String>? extra) {
    final result = R34Headers.build();
    if (extra != null) {
      // 调用方显式给的头优先；但 cookie 始终由 CookieStore 决定。
      result.addAll(extra);
    }
    if (CookieStore.hasCookies) {
      result['cookie'] = CookieStore.toHeaderValue();
    } else {
      result.remove('cookie');
    }
    return result;
  }

  Future<http.Response> _send(http.Request request) async {
    final streamed = await _client.send(request).timeout(_timeout);
    final absorbed = parseSetCookieHeader(streamed.headers['set-cookie']);
    if (absorbed.isNotEmpty) {
      await CookieStore.merge(absorbed);
      LogUtil.info('absorbed ${absorbed.length} cookies from response');
    }
    return http.Response.fromStream(streamed);
  }

  /// 解析 `Set-Cookie`。
  ///
  /// `http` 包会把多条 `Set-Cookie` 用 `, ` 拼成一个字符串，而 `Expires` 的值
  /// 本身就含逗号（`Expires=Wed, 21 Oct 2026 07:28:00 GMT`），所以先用
  /// 「逗号后面紧跟 `名字=`」的边界切段，再交给 dart:io 的解析器逐段处理。
  static Map<String, String> parseSetCookieHeader(String? raw) {
    final result = <String, String>{};
    if (raw == null || raw.trim().isEmpty) {
      return result;
    }

    for (final segment in raw.split(RegExp(r',(?=\s*[A-Za-z0-9_\-\.]+=)'))) {
      final trimmed = segment.trim();
      if (trimmed.isEmpty) {
        continue;
      }
      try {
        final cookie = Cookie.fromSetCookieValue(trimmed);
        if (cookie.name.isEmpty) {
          continue;
        }
        result[cookie.name] = cookie.value;
      } catch (e) {
        LogUtil.warn('skip unparsable set-cookie: $trimmed');
      }
    }
    return result;
  }

  void close() => _client.close();
}
