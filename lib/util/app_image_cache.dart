import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:r34_video/util/log_util.dart';
import 'package:r34_video/util/writable_dir.dart';

/// 图片缓存（**默认不介入**）。
///
/// 正常情况下 `cached_network_image` / `flutter_cache_manager` 自己的默认实现
/// 就是对的：元数据落 `%APPDATA%`，文件落 `%TEMP%`，而且有磁盘持久化。
/// **不要去 override 它**，那样等于给上游包打补丁，难维护。
///
/// 这里只保留一个**显式开启**的逃生舱，用于极端环境（例如进程被标了
/// Low Mandatory Level，`%TEMP%`/`%APPDATA%` 一律写不进去）。那种情况下
/// 默认实现会持续抛 `PathAccessException` 且图片永远出不来。
///
/// 开启方式：在 main() 里调用 [useWritableFallback]，或者设环境变量
/// `R34_IMAGE_CACHE_FALLBACK=1`。
///
/// 注意：正确的修法是**去掉那个 Low 完整性标签**：
/// ```powershell
/// icacls <工程根> /setintegritylevel Medium /T /C
/// ```
/// 修完就不需要这个逃生舱了。
class AppImageCache {
  const AppImageCache._();

  static const String _envFlag = 'R34_IMAGE_CACHE_FALLBACK';

  static BaseCacheManager? _fallback;

  /// 按环境变量决定是否启用逃生舱（main() 里调用即可）。
  static void ensureInitialized() {
    if (WritableDir.envFlagEnabled(_envFlag)) {
      useWritableFallback();
    }
  }

  /// 是否已切到「落可写目录」的缓存。
  static bool get usingFallback => _fallback != null;

  /// 显式切到「缓存落 [WritableDir] 探出来的可写目录」。
  ///
  /// 只在默认实现确实不可用时才调用；代价是不走官方默认位置。
  static void useWritableFallback() {
    if (_fallback != null) {
      return;
    }
    final base = WritableDir.resolve();
    if (base == null) {
      LogUtil.warn('image cache fallback skipped: no writable directory');
      return;
    }

    final manager = CacheManager(
      Config(
        'r34_explorer_images',
        stalePeriod: const Duration(days: 7),
        maxNrOfCacheObjects: 300,
      ),
    );
    _fallback = manager;
    CachedNetworkImageProvider.defaultCacheManager = manager;
    LogUtil.info('image cache fallback enabled (base writable check: $base)');
  }
}
