import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:http/io_client.dart';
import 'package:r34_video/constant/r34_const.dart';
import 'package:r34_video/repo/entity/r34_login.dart';
import 'package:http/http.dart' as http;
import 'package:r34_video/repo/local_repo.dart';
import 'package:r34_video/util/http_trace_util.dart';

class R34UserRepo {
  static const String defaultCookie =
      '__ddg8_=xMjU37i6p0DUvUcF; __ddg9_=89.185.25.148; __ddg10_=1738246162; __ddg1_=8GmM9WLqPF5wFNTWTugH; PHPSESSID=6vvbfblqmribbo7lf2vd21vfne; kt_ips=89.185.25.148; kt_tcookie=1; kt_rt_popAccess=1';
  static final Map<String, String> defaultHeader = Map.of(R34Const.headers)
    ..addAll({'cookie': defaultCookie});

  static const String loginUrl = 'https://rule34video.com/login/';

  static Future<R34LoginRes?> login(String username, String password) async {
    http.Response? res;
    try {
      res = await http.post(
        Uri.parse(loginUrl),
        headers: defaultHeader,
        body: R34LoginRequest(username: username, pass: password).toJson(),
      );
    } catch (e) {
      log(e.toString());
      HttpTraceUtil.handleConnectionError(e);
    }

    if (res!.statusCode != 200) {
      HttpTraceUtil.handleHttpError(res.statusCode);
      return null;
    }

    Map<String, String> cookies = {};
    final setCookieList = res.headersSplitValues['set-cookie'] ?? <String>[];
    for (var setCookie in setCookieList) {
      final cookie = Cookie.fromSetCookieValue(setCookie);
      cookies[cookie.name] = cookie.value;
    }

    final body = jsonDecode(res.body);
    log('loginRes: $body');
    final loginRes = R34LoginRes.fromJson(body, cookies);
    LocalUserRepo.saveUserData(loginRes);
    return loginRes;
  }
}
