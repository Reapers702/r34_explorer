import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:r34_video/util/log_util.dart';

/// 一条 cookie。
class CookieEntry {
  final String name;
  final String value;

  const CookieEntry(this.name, this.value);

  @override
  String toString() => '$name=$value';
}

/// Cookie 仓库。
///
/// 早期版本把 cookie 直接硬编码在 `R34Const.headers` 里（写死在 2025 年的
/// `__ddg*` / `PHPSESSID`），一旦站点侧失效，**所有**请求都会瞬间挂掉，
/// 而且用户登录成功后拿到的 cookie 也从没被写回到请求里。
///
/// 这里改成：内存 + SharedPreferences 持久化，所有请求统一从
/// `R34Client` 注入，并把服务端 `Set-Cookie` 自动回写。
class CookieStore {
  CookieStore._();

  static const String _prefsKey = 'r34_cookies';

  /// 站点用的 Cloudflare/DDG 保护 cookie，缺失时会直接 403。
  static const List<String> _protectionPrefixes = ['__ddg'];

  static final Map<String, String> _cookies = {};

  static bool _loaded = false;

  /// 已加载的 cookie 数量，供设置页展示。
  static int get length => _cookies.length;

  static bool get hasCookies => _cookies.isNotEmpty;

  /// 是否已经拿到风控 cookie（`__ddg*`）。没有的话请求大概率会被拦。
  static bool get hasProtectionCookie =>
      _cookies.keys.any((key) => _protectionPrefixes.any(key.startsWith));

  static Map<String, String> get all => Map.unmodifiable(_cookies);

  static Future<void> load() async {
    if (_loaded) {
      return;
    }
    _loaded = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        decoded.forEach((key, value) {
          final text = value?.toString() ?? '';
          if (text.isNotEmpty) {
            _cookies[key] = text;
          }
        });
      }
    } catch (e, st) {
      LogUtil.error('load cookies failed: $e\n$st');
    }

    // 兜底种子：让用户首次打开时至少能尝试访问，之后会被真实的 Set-Cookie 覆盖。
    if (_cookies.isEmpty) {
      _cookies.addAll(parseCookieString(R34ConstSeed.cookie));
    }
  }

  /// 解析 `a=1; b=2` 这种 cookie 串。
  static Map<String, String> parseCookieString(String raw) {
    final result = <String, String>{};
    for (final part in raw.split(';')) {
      final trimmed = part.trim();
      if (trimmed.isEmpty) {
        continue;
      }
      final index = trimmed.indexOf('=');
      if (index <= 0) {
        continue;
      }
      final name = trimmed.substring(0, index).trim();
      final value = trimmed.substring(index + 1).trim();
      if (name.isNotEmpty) {
        result[name] = value;
      }
    }
    return result;
  }

  /// 覆写整份 cookie（手动录入用）。
  static Future<void> replaceFromString(String raw) async {
    await replaceAll(parseCookieString(raw));
  }

  /// 覆写整份 cookie（自动抓取用）。
  static Future<void> replaceAll(Map<String, String> cookies) async {
    await load();
    _cookies
      ..clear()
      ..addAll(
        cookies.map((key, value) => MapEntry(key, value.toString())),
      );
    await _persist();
  }

  /// 合并（同名覆盖），用于吸收服务端的 `Set-Cookie`。
  static Future<void> merge(Map<String, String> cookies) async {
    if (cookies.isEmpty) {
      return;
    }
    await load();
    var changed = false;
    cookies.forEach((key, value) {
      final text = value.toString();
      if (text.isEmpty || _cookies[key] == text) {
        return;
      }
      _cookies[key] = text;
      changed = true;
    });
    if (changed) {
      await _persist();
    }
  }

  static Future<void> clear() async {
    _cookies.clear();
    await _persist();
  }

  static String? read(String name) => _cookies[name];

  /// 拼成请求头里的 Cookie 值。
  static String toHeaderValue() {
    return _cookies.entries.map((e) => '${e.key}=${e.value}').join('; ');
  }

  static Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, jsonEncode(_cookies));
    } catch (e, st) {
      LogUtil.error('persist cookies failed: $e\n$st');
    }
  }
}

/// 首启兜底 cookie。
///
/// 只是「有比没有好」的种子，真实值会由服务端 `Set-Cookie` 覆盖；
/// 如果失效了，用户可以在 设置 → Cookie 里手填，或走网页登录。
///
/// 注意：`__ddg10_` 必须带当前时间戳，所以这里是 getter 而不是常量。
class R34ConstSeed {
  const R34ConstSeed._();

  static String get cookie =>
      '__ddg10_=${DateTime.now().millisecondsSinceEpoch ~/ 1000};';
}
