import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:r34_video/util/log_util.dart';

/// 探测「本进程真的写得进去」的目录。
///
/// 正常环境用不到它 —— 标准位置（`%TEMP%` / `%APPDATA%`）本来就该可写。
/// 它只服务于一种异常情况：**工程目录被打了 `Low Mandatory Level` 标签**，
/// 于是从这里编译/启动的进程都是低完整性，写标准位置一律 `Access denied`。
///
/// 正确的修法永远是去掉那个标签：
/// ```powershell
/// icacls <工程根> /setintegritylevel Medium /T /C
/// ```
/// 这个探测只作为「不想动系统权限时」的兜底，默认不启用。
class WritableDir {
  const WritableDir._();

  static String? _cache;
  static bool _resolved = false;

  /// 是否探测到了可写目录（供日志/诊断使用）。
  static String? get selected => _cache;

  /// 读一个「开启某功能」的环境变量开关。
  static bool envFlagEnabled(String name) {
    final value = Platform.environment[name];
    if (value == null) {
      return false;
    }
    final normalized = value.trim().toLowerCase();
    return normalized == '1' ||
        normalized == 'true' ||
        normalized == 'yes' ||
        normalized == 'on';
  }

  /// 取一个可写目录（结果缓存，只探测一次）；全失败返回 null。
  static String? resolve() {
    if (_resolved) {
      return _cache;
    }
    _resolved = true;

    for (final candidate in candidates()) {
      if (candidate.isEmpty) {
        continue;
      }
      if (_canWrite(candidate)) {
        _cache = candidate;
        LogUtil.info('writable dir = $candidate');
        return _cache;
      }
    }

    LogUtil.warn('no writable directory found');
    return null;
  }

  /// 候选目录，按优先级。
  ///
  /// 低完整性进程能写的位置，通常是 ACL 里带 `Everyone` / `Authenticated Users`
  /// 的目录（工作区往往就是这种），所以工程目录排在标准位置前面。
  @visibleForTesting
  static Iterable<String> candidates() sync* {
    final env = Platform.environment;

    final override = env['R34_WRITABLE_DIR'];
    if (override != null && override.isNotEmpty) {
      yield override;
    }

    final cwd = Directory.current.path;
    yield '$cwd${Platform.pathSeparator}.runtime';

    try {
      final exeDir = File(Platform.resolvedExecutable).parent.path;
      yield '$exeDir${Platform.pathSeparator}.runtime';
    } catch (_) {
      // 忽略
    }

    final local = env['LOCALAPPDATA'];
    if (local != null && local.isNotEmpty) {
      yield '$local${Platform.pathSeparator}r34_explorer';
    }
    final appData = env['APPDATA'];
    if (appData != null && appData.isNotEmpty) {
      yield '$appData${Platform.pathSeparator}top.reapers.r34explorer';
    }

    yield '${Directory.systemTemp.path}${Platform.pathSeparator}r34_explorer';
  }

  static bool _canWrite(String dir) {
    try {
      final target = Directory(dir);
      if (!target.existsSync()) {
        target.createSync(recursive: true);
      }
      final probe = File('$dir${Platform.pathSeparator}.write_probe');
      probe.writeAsStringSync('${DateTime.now().millisecondsSinceEpoch}');
      probe.deleteSync();
      return true;
    } catch (e) {
      debugPrint('WritableDir probe failed for $dir: $e');
      return false;
    }
  }
}
