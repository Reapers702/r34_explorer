import 'dart:math';

import 'package:drag_bottom_sheet/entity/data.dart';

enum VideoDuration {
  all,
  lessThanOneMin,
  oneMinToFiveMin,
  moreThanFiveMin,
}

class SearchOption {
  VideoDuration duration;

  SearchOption({this.duration = VideoDuration.all});
}

class DataRepo {
  static const List<int> imageSize = [];
  static Random random = Random.secure();

  static Future<List<Data>> getDataList(SearchOption option) async {
    List<Data> data = [];
    for (int i = 0; i < 29; i++) {
      int width = random.nextInt(400);
      int height = width * 9 ~/ 16;
      String imageUrl = 'https://picsum.photos/$width/$height';
      data.add(Data(
          'index ${i}dsaidasjodasdjosadjoaidjiossadasdasdasdasdsadadio',
          imageUrl,
          imageUrl));
    }
    return data;
  }
}
