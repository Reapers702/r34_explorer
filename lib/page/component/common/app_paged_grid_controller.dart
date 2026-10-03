import 'dart:async';

import 'package:flutter/material.dart';

/// 一页视频数据。
class VideoPageResult {
  final List<Object> videos;
  final int pageCount;

  const VideoPageResult(this.videos, this.pageCount);
}

typedef VideoPageLoader = Future<VideoPageResult> Function(int page);

/// 分页网格的数据控制。
///
/// 首页和搜索结果页原本各写一遍 PageView + `Map<int, List<R34Video>>` + loading 标志，
/// 逻辑几乎一字不差。抽到这里后，两边只提供「第 N 页怎么加载」。
class AppPagedGridController extends ChangeNotifier {
  AppPagedGridController({required this.loader, this.initialPage = 1});

  final VideoPageLoader loader;

  final int initialPage;

  int _currentPage = 1;
  int _pageCount = 1;
  bool _loading = false;
  bool _disposed = false;

  /// 用 Object 存是为了避开实体类型的循环 import，取值处再 cast。
  final Map<int, List<Object>> _pages = {};

  int get currentPage => _currentPage;
  int get pageCount => _pageCount;
  bool get loading => _loading;
  bool get isEmpty => _pages[_currentPage]?.isEmpty ?? true;

  List<Object> videosOf(int page) => _pages[page] ?? const [];

  bool hasPage(int page) => _pages.containsKey(page);

  /// 条件变化：清空并回到第 1 页重新加载。
  Future<void> reset() async {
    _pages.clear();
    _currentPage = initialPage;
    _pageCount = 1;
    _safeNotify();
    await loadPage(initialPage);
  }

  Future<void> loadPage(int page) async {
    if (_loading || _disposed) {
      return;
    }
    if (_pages.containsKey(page)) {
      _currentPage = page;
      _safeNotify();
      return;
    }

    _loading = true;
    _currentPage = page;
    _safeNotify();

    try {
      final result = await loader(page);
      if (_disposed) {
        return;
      }
      _pages[page] = result.videos;
      if (result.pageCount > 0) {
        _pageCount = result.pageCount;
      }
    } finally {
      _loading = false;
      _safeNotify();
    }
  }

  /// PageView 切换时调用。
  void onPageChanged(int page) {
    _currentPage = page;
    if (_pages.containsKey(page)) {
      _safeNotify();
      return;
    }
    unawaited(loadPage(page));
  }

  void _safeNotify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
