import 'dart:convert';

import 'package:html/parser.dart' as parser;
import 'package:r34_video/constant/r34_const.dart';
import 'package:r34_video/repo/cookie_store.dart';
import 'package:r34_video/repo/entity/r34_login.dart';
import 'package:r34_video/repo/local_repo.dart';
import 'package:r34_video/repo/r34_client.dart';
import 'package:r34_video/util/http_trace_util.dart';
import 'package:r34_video/util/log_util.dart';

class R34UserRepo {
  /// 最近一次登录失败的原因（诊断用，不含凭据）。
  static String? _lastFailure;

  /// 供联调/日志查看的失败原因。
  static String? get lastFailure => _lastFailure;

  /// 登录。
  ///
  /// 站点的登录表单带一个 `remember_me_csrf_token`，而且必须先访问 `/login/`
  /// 建立会话（拿到 `kt_acctoken` / `__ddg*`）才能提交，否则一定会被拒。
  /// 早期版本既没取 token 也用的是写死的 cookie，所以基本永远登不上。
  ///
  /// 这里分两步：
  /// 1. GET `/login/` → 抽 CSRF token（会话 cookie 由 [R34Client] 自动收好）；
  /// 2. 带 token POST 账号密码。
  ///
  /// 注意：`username` 字段收的是**邮箱**（页面 placeholder 就是
  /// "Please enter your email"）。
  static Future<R34LoginRes?> login(String username, String password) async {
    try {
      final token = await _fetchCsrfToken();
      if (token == null || token.isEmpty) {
        LogUtil.warn('login aborted: no csrf token from /login/');
        _lastFailure = 'no-csrf-token';
        return null;
      }
      _lastFailure = null;

      final res = await R34Client.instance.post(
        Uri.https(R34Const.host, '/login/'),
        body: {
          ...R34LoginRequest(username: username, pass: password).toJson(),
          'remember_me_csrf_token': token,
        },
      );

      if (res.statusCode != 200) {
        HttpTraceUtil.handleHttpError(res.statusCode);
        _lastFailure = 'http-${res.statusCode}';
        return null;
      }

      final dynamic decoded = jsonDecode(res.body);
      if (decoded is! Map<String, dynamic>) {
        LogUtil.warn('unexpected login response: ${res.body}');
        _lastFailure = 'not-json';
        return null;
      }

      // 失败时服务端给 {"status":"failure","errors":[...]}，先判 status，
      // 否则下面 fromJson 会因为缺 data 直接抛异常。
      if (decoded['status'] != 'success') {
        LogUtil.warn('login rejected: ${res.body}');
        _lastFailure = 'rejected: ${res.body}';
        return null;
      }

      final data = decoded['data'];
      if (data is! Map<String, dynamic> || data['user_id'] == null) {
        LogUtil.warn('login success but data invalid: ${res.body}');
        _lastFailure = 'bad-data: ${res.body}';
        return null;
      }

      // CookieStore 已在 R34Client 里收好服务端下发的 cookie，这里取快照落库，
      // 避免用户之后手动改了 cookie 导致记录对不上。
      final cookies = Map<String, String>.of(CookieStore.all);
      cookies.addAll(R34Client.parseSetCookieHeader(res.headers['set-cookie']));

      final loginRes = R34LoginRes.fromJson(decoded, cookies);
      await LocalUserRepo.saveUserData(loginRes);
      return loginRes;
    } catch (e, st) {
      LogUtil.error('login failed: $e\n$st');
      _lastFailure = 'exception: $e';
      return null;
    }
  }

  /// 拉登录页并抽出 CSRF token。
  static Future<String?> _fetchCsrfToken() async {
    final res = await R34Client.instance.get(
      Uri.https(R34Const.host, '/login/'),
    );
    if (res.statusCode != 200) {
      HttpTraceUtil.handleHttpError(res.statusCode);
      return null;
    }

    final document = parser.parse(res.body);
    final input = document.querySelector('input[name="remember_me_csrf_token"]');
    final token = input?.attributes['value']?.trim();
    return (token == null || token.isEmpty) ? null : token;
  }
}
