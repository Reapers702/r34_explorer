import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:r34_video/provider/login_user_provider.dart';
import 'package:r34_video/repo/local_repo.dart';
import 'package:r34_video/repo/r34_user_repo.dart';
import 'package:r34_video/theme/app_colors.dart';
import 'package:r34_video/theme/app_dimens.dart';
import 'package:r34_video/util/log_util.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    if (username.isEmpty || password.isEmpty) {
      _snack('请填写用户名和密码');
      return;
    }

    setState(() => _isLoading = true);
    try {
      await R34UserRepo.login(username, password);
    } catch (e, st) {
      LogUtil.error('login failed: $e\n$st');
      if (mounted) {
        _snack('登录失败，请稍后重试');
      }
      return;
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }

    if (!mounted) {
      return;
    }

    if (!await LocalUserRepo.isLogin()) {
      _snack('登录失败，请检查账号密码');
      return;
    }

    final provider = context.read<LoginUserProvider>();
    provider.setUserId(await LocalUserRepo.getUserId());
    provider.setDisplayName(await LocalUserRepo.getDisplayName());

    if (mounted) {
      Navigator.of(context).maybePop();
    }
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('登录')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppSpacing.xxl),
              const Text(
                '登录 Rule34 Explorer',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: AppSpacing.xs),
              const Text(
                '登录后可查看自己的上传与收藏',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12.5, color: AppColors.textHint),
              ),
              const SizedBox(height: AppSpacing.xxl),
              TextField(
                controller: _usernameController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: '用户名',
                  prefixIcon: Icon(Icons.person_outline_rounded, size: 20),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              TextField(
                controller: _passwordController,
                obscureText: true,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) {
                  if (!_isLoading) {
                    _login();
                  }
                },
                decoration: const InputDecoration(
                  labelText: '密码',
                  prefixIcon: Icon(Icons.lock_outline_rounded, size: 20),
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
              SizedBox(
                height: 46,
                child: FilledButton(
                  onPressed: _isLoading ? null : _login,
                  child: _isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('登录'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
