import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:r34_video/util/log_util.dart';

/// 图片缓存。
///
/// 背景：`flutter_cache_manager` 在 Windows 上默认用
/// `JsonCacheInfoRepository`，它会去要 `getApplicationSupportDirectory()`
/// （`%APPDATA%\<公司>\<产品>\`）并**创建目录**。在受限进程里这一步会抛
/// `PathAccessException: Creation failed ... 拒绝访问`，而且是在异步初始化里，
/// 属于未捕获异常 —— 结果就是**图片一直出不来**（每次取图都重新走一遍失败路径）。
///
/// 这里的做法：不碰那个目录。
/// * `repo` 用 [NonStoringObjectProvider]（纯内存元数据，不做数据库）；
/// * 文件落到 `getTemporaryDirectory()`，失败再退到系统临时目录；
/// * 图片的“内存缓存”由 Flutter 自己的 `ImageCache` 负责，所以重复渲染不会重复下载。
///
/// 代价值得说明：**没有磁盘持久化**，重启 App 后图片会重新下载一次。
/// 等哪天那个目录可写了，把 [useDiskCache] 打开即可恢复。
class AppImageCache {
  const AppImageCache._();

  /// 镜像的缓存 key，同时作为临时目录名。
  static const String cacheKey = 'r34_explorer_images';

  /// 是否启用磁盘缓存。当前环境（Windows 受限进程）建不了应用数据目录，故关闭。
  static const bool useDiskCache = false;

  static BaseCacheManager? _manager;

  /// 全局替换 `CachedNetworkImage` 的默认缓存管理器。
  ///
  /// 用静态字段覆盖，是为了让所有调用点（缩略图、详情大图、头像…）一次性生效，
  /// 不必每个 `CachedNetworkImage` 都传 `cacheManager`。
  static void ensureInitialized() {
    if (_manager != null) {
      return;
    }

    try {
      final manager = CacheManager(
        Config(
          cacheKey,
          stalePeriod: const Duration(days: 7),
          maxNrOfCacheObjects: 300,
          // 关键：绕过 JsonCacheInfoRepository / sqlite，
          // 也就绕过了 getApplicationSupportDirectory()。
          repo: NonStoringObjectProvider(),
        ),
      );
      _manager = manager;
      CachedNetworkImageProvider.defaultCacheManager = manager;
      LogUtil.info('image cache: using non-storing repo (memory metadata)');
    } catch (e, st) {
      // 构造本身失败也不能让 App 起不来，交给默认实现。
      LogUtil.error('image cache init failed: $e\n$st');
    }
  }
}
