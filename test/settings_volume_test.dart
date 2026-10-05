import 'package:flutter_test/flutter_test.dart';
import 'package:r34_video/provider/settings_provider.dart';

void main() {
  group('SettingsModel 音量记忆', () {
    test('默认音量是 100', () {
      expect(SettingsModel.defaultSettings().volume, 100);
    });

    test('音量可以序列化并还原', () {
      final source = SettingsModel(volume: 66);
      final restored = SettingsModel.fromJson(source.toJson());
      expect(restored.volume, 66);
    });

    test('旧存档没有 volume 字段时回退为默认 100', () {
      final model = SettingsModel.fromJson({
        'playUrlType': 'webPlay',
        'parseAutoRedirect': true,
        'autoPlay': true,
      });
      expect(model.volume, 100);
    });

    test('音量低于 0 会被 clamp 到 0', () {
      final model = SettingsModel.fromJson({
        'playUrlType': 'webPlay',
        'parseAutoRedirect': true,
        'autoPlay': true,
        'volume': -5,
      });
      expect(model.volume, 0);
    });
  });
}