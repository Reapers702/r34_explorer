import 'dart:io' as io;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:file/file.dart' as pf;
import 'package:file/local.dart' as plocal;
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:r34_video/util/log_util.dart';
import 'package:r34_video/util/writable_dir.dart';

/// 图片缓存。
///
/// 背景（实测）：`flutter_cache_manager` 默认走两处**可能不可写**的位置 ——
/// * 元数据：`JsonCacheInfoRepository` -> `getApplicationSupportDirectory()`
///   （`%APPDATA%\<公司>\<产品>\`）；
/// * 文件：`IOFileSystem` -> `getTemporaryDirectory()`（`%TEMP%\<cacheKey>`）。
///
/// 受限身份下这两处都会 `Access denied`，而异常发生在异步初始化里，
/// 属未捕获异常 —— 后果是**缓存库始终不可用，图片一直出不来**。
///
/// 这里两处都换掉：
/// * `repo` 用 [NonStoringObjectProvider]（纯内存元数据，不碰数据库）；
/// * `fileSystem` 换成 [_WritableFileSystem]（自己实现，只放可写目录）。
///
/// 注意**不要**去继承官方 `IOFileSystem`：它的 `_fileDir` 是急切初始化的
/// （`IOFileSystem(key) : _fileDir = createDirectory(key)`），父类构造时就一定会
/// 去建 `%TEMP%\<key>`，照样抛异常，覆写 `createFile` 救不了。
///
/// 想固定缓存位置可设环境变量 `R34_WRITABLE_DIR`。
class AppImageCache {
  const AppImageCache._();

  static const String cacheKey = 'r34_explorer_images';

  static BaseCacheManager? _manager;

  /// 全局替换 `CachedNetworkImage` 的默认缓存管理器。
  ///
  /// 用静态字段覆盖是为了让所有调用点（缩略图、详情大图、头像…）一次性生效，
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
          // 不再申请 getApplicationSupportDirectory()
          repo: NonStoringObjectProvider(),
          // 不再落 %TEMP% 下不可写的子目录
          fileSystem: _WritableFileSystem(),
        ),
      );
      _manager = manager;
      CachedNetworkImageProvider.defaultCacheManager = manager;
      LogUtil.info('image cache ready, base=${WritableDir.resolve()}');
    } catch (e, st) {
      // 构造失败也不能让 App 起不来。
      LogUtil.error('image cache init failed: $e\n$st');
    }
  }

  static BaseCacheManager? get manager => _manager;
}

/// 自己实现的缓存文件系统：唯一的职责是把文件放到一个**真的写得进去**的目录。
///
/// `flutter_cache_manager` 的 `FileSystem` 接口只有一个 `createFile`，
/// 所以这里实现起来很短；也正因为不继承 `IOFileSystem`，
/// 父类那个「急切创建 %TEMP% 子目录」的副作用才被彻底避开。
class _WritableFileSystem implements FileSystem {
  static const plocal.LocalFileSystem _delegate = plocal.LocalFileSystem();

  /// 缓存文件落本地前**无需**预先建目录；这里按需创建。
  pf.Directory? _dir;

  pf.Directory? _ensureDir() {
    if (_dir != null) {
      return _dir;
    }
    final base = WritableDir.resolve();
    if (base == null) {
      return null;
    }
    final dir = _delegate.directory(
      '$base${io.Platform.pathSeparator}cache_images',
    );
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    _dir = dir;
    return dir;
  }

  @override
  Future<pf.File> createFile(String name) async {
    final dir = _ensureDir();
    if (dir == null) {
      // 探测不到可写目录：抛出去，让缓存库退化为纯联网取图（图片仍能显示）。
      throw const io.FileSystemException('no writable directory available');
    }
    return dir.childFile(name);
  }
}
