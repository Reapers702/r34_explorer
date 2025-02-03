import 'package:flutter/material.dart';
import 'package:r34_video/repo/local_repo.dart';

class LoginUserProvider with ChangeNotifier {
  int? _userId;

  LoginUserProvider() {
    LocalUserRepo.isLogin()
        .then((isLogin) =>
            isLogin ? LocalUserRepo.getUserId() : Future.value(null))
        .then((userId) => setUserId(userId));
  }

  int? get userId {
    return _userId;
  }

  void setUserId(int? userId) {
    _userId = userId;
    notifyListeners();
  }

  Future<void> logout() async {
    await LocalUserRepo.logout();
    _userId = null;
    notifyListeners();
  }
}
