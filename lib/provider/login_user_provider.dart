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

  String? get userId {
    if (_userId != null) {
      return userId;
    }
  }

  void setUserId(int? userId) {
    _userId = userId;
    notifyListeners();
  }
}
