import 'package:flutter/material.dart';
import 'package:r34_video/repo/entity/r34_login.dart';
import 'package:r34_video/repo/local_repo.dart';

class LoginUserProvider with ChangeNotifier {
  int? _userId;
  String? _displayName;

  LoginUserProvider() {
    final loginFuture = LocalUserRepo.isLogin();
    loginFuture
        .then((isLogin) =>
            isLogin ? LocalUserRepo.getUserId() : Future.value(null))
        .then((userId) => setUserId(userId));
    loginFuture
        .then((isLogin) =>
            isLogin ? LocalUserRepo.getDisplayName() : Future.value(null))
        .then((name) => setDisplayName(name));
  }

  int? get userId => _userId;
  void setUserId(int? userId) {
    _userId = userId;
    notifyListeners();
  }

  String? get displayName => _displayName;
  void setDisplayName(String? displayName) {
    _displayName = displayName;
    notifyListeners();
  }

  void login(R34LoginRes loginRes) {
    _userId = loginRes.data.userId;
    _displayName = loginRes.data.displayName;
    notifyListeners();
  }

  Future<bool> logout() async {
    final re = await LocalUserRepo.logout();
    _userId = null;
    _displayName = null;
    notifyListeners();
    return re;
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'displayName': displayName,
    };
  }
}
