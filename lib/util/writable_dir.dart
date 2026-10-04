import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:r34_video/util/log_util.dart';

/// 找一块「本进程真的写得进去」的目录。
///
/// 背景（实测）：在某些 Windows 环境里，App 进程跑在受限身份下，
/// `%TEMP%` / `%APPDATA%` 这类目录的 ACL 里没有该身份能匹配的授权项，
/// 于是 `Directory.create` / `File.write` 直接 `Access denied(errno=5)`。
/// 官方组件（`path_provider`、`flutter_cache_manager`、`media_kit`）都会因此失败：
/// 图片缓存建不起来 -> 图片一直不出来。
///
/// 对照组：工程/工作区目录通常带 `Authenticated Users:(M)`，那个身份写得进去。
///
/// 所以这里**先探测、再使用**：按顺序试几个候选目录，谁先写成功就用谁；
/// 全都不行时返回 null，由调用方降级（例如只走内存缓存）。
class WritableDir {
  const WritableDir._();

  static String? _cache;
  static bool _resolved = false;

  /// 记一次结果，方便日志/诊断页展示。
  static String? get selected => _cache;

  /// 取一个可写目录（结果缓存，只探测一次）。
  static String? resolve() {
    if (_resolved) {
      return _cache;
    }
    _resolved = true;

    for (final candidate in _candidates()) {
      if (candidate.isEmpty) {
        continue;
      }
      if (_canWrite(candidate)) {
        _cache = candidate;
        LogUtil.info('writable dir = $candidate');
        return _cache;
      }
      LogUtil.warn('writable dir FAILED: $candidate');
    }

    LogUtil.error('no writable directory found; fallback to memory-only');
    return null;
  }

  static Iterable<String> _candidates() sync* {
    final env = Platform.environment;

    // 1) 显式指定优先（排查/定制用）
    final override = env['R34_WRITABLE_DIR'];
    if (override != null && override.isNotEmpty) {
      yield override;
    }

    // 2) 工作区：实测在受限身份下也可写。
    yield r'D:\develop\flutter\r34_explorer\.runtime';

    // 3) exe 同级的 data 目录（便携式布局）
    try {
      final exeDir = File(Platform.resolvedExecutable).parent.path;
      yield '$exeDir${Platform.pathSeparator}.runtime';
    } catch (_) {
      // 忽略
    }

    // 4) 用户相关的标准位置（正常环境下本来就能写）
    final local = env['LOCALAPPDATA'];
    if (local != null && local.isNotEmpty) {
      yield '$local${Platform.pathSeparator}r34_explorer';
    }
    final appData = env['APPDATA'];
    if (appData != null && appData.isNotEmpty) {
      yield '$appData${Platform.pathSeparator}top.reapers.r34explorer';
    }

    // 5) 临时目录（受限环境下通常也不行，放最后）
    yield '${Directory.systemTemp.path}${Platform.pathSeparator}r34_explorer';
    yield Directory.systemTemp.path;
  }

  static bool _canWrite(String dir) {
    try {
      final target = Directory(dir);
      if (!target.existsSync()) {
        target.createSync(recursive: true);
      }
      final probe = File(
        '$dir${Platform.pathSeparator}.write_probe',
      );
      probe.writeAsStringSync('${DateTime.now().millisecondsSinceEpoch}');
      probe.deleteSync();
      return true;
    } catch (e) {
      debugPrint('WritableDir probe failed for $dir: $e');
      return false;
    }
  }
}
