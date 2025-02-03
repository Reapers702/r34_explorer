import 'package:flutter/material.dart';
import 'package:r34_video/repo/entity/r34_video_info.dart';
import 'package:r34_video/repo/r34_search_edit_repo.dart';

class SearchEditProvider with ChangeNotifier {
  bool _historyLoading = false;
  List<String> _history = [];

  bool _trendingLoading = false;
  static List<VideoTag> _trendingTags = [];
  static List<VideoCategory> _trendingCategories = [];
  static List<VideoArtistInfo> _trendingArtists = [];

  List<VideoTag> getTrendingTags() {
    if (_trendingTags.isEmpty && !_trendingLoading) {
      _trendingLoading = true;
      R34SearchEditRepo.getTrendingData().then((value) {
        _trendingTags = value.item1;
        _trendingCategories = value.item2;
        _trendingArtists = value.item3;
        notifyListeners();
      }).whenComplete(() => _trendingLoading = false);
    }
    return _trendingTags;
  }

  List<VideoCategory> getTrendingCategories() {
    if (_trendingCategories.isEmpty && !_trendingLoading) {
      _trendingLoading = true;
      R34SearchEditRepo.getTrendingData().then((value) {
        _trendingTags = value.item1;
        _trendingCategories = value.item2;
        _trendingArtists = value.item3;
        notifyListeners();
      }).whenComplete(() => _trendingLoading = false);
    }
    return _trendingCategories;
  }

  List<VideoArtistInfo> getTrendingArtists() {
    if (_trendingArtists.isEmpty && !_trendingLoading) {
      _trendingLoading = true;
      R34SearchEditRepo.getTrendingData().then((value) {
        _trendingTags = value.item1;
        _trendingCategories = value.item2;
        _trendingArtists = value.item3;
        notifyListeners();
      }).whenComplete(() => _trendingLoading = false);
    }
    return _trendingArtists;
  }

  List<String> getSearchHistory() {
    if (_history.isEmpty && !_historyLoading) {
      _historyLoading = true;
      R34SearchEditRepo.getSearchHistory().then((value) {
        _history = value;
        notifyListeners();
      }).whenComplete(() => _historyLoading = false);
    }
    return _history;
  }

  void addSearchHistory(String searchText) async {
    try {
      await R34SearchEditRepo.addSearchHistory(searchText);
    } finally {
      notifyListeners();
    }
  }

  void removeSearchHistory(String searchText) async {
    try {
      await R34SearchEditRepo.removeSearchHistory(searchText);
    } finally {
      notifyListeners();
    }
  }
}
