import 'package:flutter/material.dart';
import 'package:r34_video/repo/local_repo.dart';

class LoginUserProvider with ChangeNotifier {
  int? _userId;
  String? _displayName;

  LoginUserProvider() {
    LocalUserRepo.isLogin()
        .then((isLogin) =>
            isLogin ? LocalUserRepo.getUserId() : Future.value(null))
        .then((userId) => setUserId(userId));
    LocalUserRepo.getDisplayName().then((name) => setDisplayName(name));
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

  Future<bool> logout() async {
    final re = await LocalUserRepo.logout();
    _userId = null;
    _displayName = null;
    notifyListeners();
    return re;
  }
}
