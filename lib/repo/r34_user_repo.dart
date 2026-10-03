import 'dart:convert';

import 'package:r34_video/constant/r34_const.dart';
import 'package:r34_video/repo/cookie_store.dart';
import 'package:r34_video/repo/entity/r34_login.dart';
import 'package:r34_video/repo/local_repo.dart';
import 'package:r34_video/repo/r34_client.dart';
import 'package:r34_video/util/http_trace_util.dart';
import 'package:r34_video/util/log_util.dart';

class R34UserRepo {
  /// 登录。
  ///
  /// 早期这里把一份写死的 `defaultCookie` 当凭据发出去，基本永远登不上；
  /// 现在用 `CookieStore` 里的当前 cookie，并且登录成功后由 [R34Client]
  /// 自动吸收服务端下发的 `Set-Cookie`（PHPSESSID 等），再落库。
  static Future<R34LoginRes?> login(String username, String password) async {
    try {
      final res = await R34Client.instance.post(
        Uri.https(R34Const.host, '/login/'),
        body: R34LoginRequest(username: username, pass: password).toJson(),
      );

      if (res.statusCode != 200) {
        HttpTraceUtil.handleHttpError(res.statusCode);
        return null;
      }

      final body = jsonDecode(res.body);
      if (body is! Map<String, dynamic>) {
        LogUtil.warn('unexpected login response: ${res.body}');
        return null;
      }
      if (body['status'] != 'success') {
        LogUtil.warn('login rejected: ${res.body}');
        return null;
      }

      // CookieStore 已在 R34Client 里收好服务端下发的 cookie，这里取快照落库，
      // 避免用户之后手动改了 cookie 导致历史记录对不上。
      final cookies = Map<String, String>.of(CookieStore.all);
      cookies.addAll(R34Client.parseSetCookieHeader(res.headers['set-cookie']));

      final loginRes = R34LoginRes.fromJson(body, cookies);
      await LocalUserRepo.saveUserData(loginRes);
      return loginRes;
    } catch (e, st) {
      LogUtil.error('login failed: $e\n$st');
      return null;
    }
  }
}
