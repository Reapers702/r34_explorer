import 'package:flutter/foundation.dart';
import 'package:r34_video/repo/entity/r34_video_info.dart';
import 'package:r34_video/repo/r34_search_edit_repo.dart';
import 'package:r34_video/util/log_util.dart';

/// 搜索编辑页的数据。
///
/// 早期三个 `getTrendingXxx()` 各自判断一次 `_trendingLoading`，
/// 同一帧里连续调用会连发三次请求；这里合并成一次 `loadTrending()`。
class SearchEditProvider extends ChangeNotifier {
  bool _historyLoading = false;
  List<String> _history = [];

  bool _trendingLoading = false;
  bool _trendingLoaded = false;

  List<VideoTag> _trendingTags = [];
  List<VideoCategory> _trendingCategories = [];
  List<VideoArtistInfo> _trendingArtists = [];

  List<String> get history => List.unmodifiable(_history);

  List<VideoTag> get trendingTags => List.unmodifiable(_trendingTags);

  List<VideoCategory> get trendingCategories =>
      List.unmodifiable(_trendingCategories);

  List<VideoArtistInfo> get trendingArtists =>
      List.unmodifiable(_trendingArtists);

  bool get trendingLoading => _trendingLoading;

  bool get historyLoading => _historyLoading;

  Future<void> loadHistory() async {
    if (_historyLoading || _history.isNotEmpty) {
      return;
    }
    _historyLoading = true;
    notifyListeners();
    try {
      _history = await R34SearchEditRepo.getSearchHistory();
    } catch (e, st) {
      LogUtil.error('load search history failed: $e\n$st');
    } finally {
      _historyLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadTrending() async {
    if (_trendingLoading || _trendingLoaded) {
      return;
    }
    _trendingLoading = true;
    notifyListeners();
    try {
      final result = await R34SearchEditRepo.getTrendingData();
      _trendingTags = result.item1;
      _trendingCategories = result.item2;
      _trendingArtists = result.item3;
      _trendingLoaded = true;
    } catch (e, st) {
      LogUtil.error('load trending failed: $e\n$st');
    } finally {
      _trendingLoading = false;
      notifyListeners();
    }
  }

  Future<void> addSearchHistory(String searchText) async {
    final text = searchText.trim();
    if (text.isEmpty) {
      return;
    }
    try {
      await R34SearchEditRepo.addSearchHistory(text);
      _history = await R34SearchEditRepo.getSearchHistory();
    } catch (e, st) {
      LogUtil.error('add search history failed: $e\n$st');
    } finally {
      notifyListeners();
    }
  }

  Future<void> removeSearchHistory(String searchText) async {
    try {
      await R34SearchEditRepo.removeSearchHistory(searchText);
      _history = await R34SearchEditRepo.getSearchHistory();
    } catch (e, st) {
      LogUtil.error('remove search history failed: $e\n$st');
    } finally {
      notifyListeners();
    }
  }

  Future<void> clearSearchHistory() async {
    try {
      await R34SearchEditRepo.clearSearchHistory();
      _history = [];
    } finally {
      notifyListeners();
    }
  }
}
