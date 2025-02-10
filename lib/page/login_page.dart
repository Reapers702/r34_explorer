import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:r34_video/provider/login_user_provider.dart';
import 'package:r34_video/repo/local_repo.dart';
import 'package:r34_video/repo/r34_user_repo.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _login() async {
    setState(() {
      _isLoading = true;
    });

    String username = _usernameController.text;
    String password = _passwordController.text;

    try {
      await R34UserRepo.login(username, password);
    } catch (e) {
      log('发生错误: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }

    if (context.mounted) {
      final isLogin = await LocalUserRepo.isLogin();
      final userId = await LocalUserRepo.getUserId();
      final displayName = await LocalUserRepo.getDisplayName();
      if (isLogin) {
        final loginUserProvider = context.read<LoginUserProvider>();
        loginUserProvider.setUserId(userId);
        loginUserProvider.setDisplayName(displayName);
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('登录页'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _usernameController,
              decoration: const InputDecoration(
                labelText: '用户名',
              ),
            ),
            const SizedBox(height: 16.0),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(
                labelText: '密码',
              ),
              obscureText: true,
            ),
            const SizedBox(height: 32.0),
            ElevatedButton(
              onPressed: _isLoading ? null : _login,
              child: _isLoading
                  ? const CircularProgressIndicator()
                  : const Text('登录'),
            ),
          ],
        ),
      ),
    );
  }
}
