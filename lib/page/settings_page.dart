import 'package:flutter/material.dart';
import 'package:flutter_settings_ui/flutter_settings_ui.dart';
import 'package:provider/provider.dart';
import 'package:r34_video/provider/login_user_provider.dart';
import 'package:r34_video/provider/settings_provider.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  @override
  Widget build(BuildContext context) {
    final loginProvider = context.watch<LoginUserProvider>();
    final settingsProvider = context.read<SettingsProvider>();

    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Settings'),
          automaticallyImplyLeading: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: SettingsList(
          sections: [
            SettingsSection(
              title: const Text('基础设置'),
              tiles: <SettingsTile>[
                SettingsTile.navigation(
                  leading: const Icon(Icons.language),
                  title: const Text('视频链接解析方式'),
                  value: Text(settingsProvider.settingsModel!.playUrlType.desc),
                  onPressed: (context) {
                    _showPlayUrlTypeDialog(context);
                  },
                ),
              ],
            ),
            SettingsSection(
              title: const Text('账户设置'),
              tiles: <SettingsTile>[
                SettingsTile.navigation(
                  leading: const Icon(Icons.account_circle),
                  title: Text(loginProvider.displayName ?? '未登录'),
                  onPressed: (context) {
                    if (loginProvider.displayName != null) {
                      _showLogoutDialog(context);
                    }
                  },
                ),
              ],
            ),
            SettingsSection(
              title: const Text('关于'),
              tiles: [
                SettingsTile(
                  title: const Text('版本号'),
                  value: const Text('1.0.0'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<bool?> _showLogoutDialog(BuildContext context) async {
    final loginProvider = context.read<LoginUserProvider>();
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('退出账号'),
          content: const SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text('你确定要登出当前账号吗'),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('取消'),
              onPressed: () {
                Navigator.of(context).pop(false);
              },
            ),
            TextButton(
              child: const Text('确定'),
              onPressed: () {
                setState(() {
                  loginProvider.logout();
                });
                Navigator.of(context).pop(true);
              },
            ),
          ],
        );
      },
    );
  }

  void _showPlayUrlTypeDialog(BuildContext context) {
    final settingsProvider = context.read<SettingsProvider>();
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('选择解析方式'),
          content: SingleChildScrollView(
            child: ListBody(
              children: PlayUrlType.values.map((urlType) {
                return RadioListTile<PlayUrlType>(
                  title: Text(urlType.desc),
                  value: urlType,
                  groupValue: settingsProvider.settingsModel!.playUrlType,
                  onChanged: (PlayUrlType? value) {
                    setState(() {
                      settingsProvider.settingsModel!.playUrlType = value!;
                      settingsProvider.saveSettings();
                    });
                    Navigator.of(context).pop();
                  },
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }
}
