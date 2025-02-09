import 'dart:convert';
import 'dart:developer';

import 'package:r34_video/repo/entity/r34_login.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalUserRepo {
  static Future<void> saveUserData(R34LoginRes loginRes) async {
    final resData = loginRes.data;
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString('displayName', resData.displayName);
    prefs.setInt('userId', resData.userId);
    prefs.setString('username', resData.username);
    prefs.setString('cookies', jsonEncode(loginRes.cookies));
    prefs.setBool('login', true);
    log('save user data end');
  }

  static Future<bool> isLogin() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    log('isLogin: ${prefs.getBool('login')}');
    return prefs.getBool('login') ?? false;
  }

  static Future<String> getDisplayName() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('displayName') ?? '';
  }

  static Future<Map<String, String>> getCookie() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return jsonDecode(prefs.getString('cookies') ?? '{}');
  }

  static Future<int> getUserId() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getInt('userId') ?? 0;
  }

  static Future<bool> logout() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return await prefs.remove('login') &&
        await prefs.remove('userId') &&
        await prefs.remove('displayName') &&
        await prefs.remove('username');
  }
}
