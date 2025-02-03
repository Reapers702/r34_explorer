import 'dart:convert';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:r34_video/repo/entity/r34_search_request.dart';

class SearchResultPageArg {
  late String searchText;
  late SearchKeywordType keywordType;
  SearchResultPageArg({required String searchText}) {
    if (searchText.startsWith('t:')) {
      this.searchText = searchText.substring(2);
      keywordType = SearchKeywordType.tag;
    } else if (searchText.startsWith('c:')) {
      this.searchText = searchText.substring(2);
      keywordType = SearchKeywordType.category;
    } else if (searchText.startsWith('a:')) {
      this.searchText = searchText.substring(2);
      keywordType = SearchKeywordType.artist;
    } else {
      this.searchText = searchText;
      keywordType = SearchKeywordType.keyword;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'searchText': searchText,
      'keywordType': keywordType.name,
    };
  }
}

class SearchResultPage extends StatefulWidget {
  const SearchResultPage({super.key});

  @override
  State<SearchResultPage> createState() => _SearchResultPageState();
}

class _SearchResultPageState extends State<SearchResultPage> {
  SearchResultPageArg? arg;

  @override
  Widget build(BuildContext context) {
    arg ??= ModalRoute.of(context)!.settings.arguments as SearchResultPageArg;
    log('search result page arg: ${jsonEncode(arg!.toJson())}');

    return const Placeholder();
  }
}
