import 'package:flutter_test/flutter_test.dart';
import 'package:r34_video/constant/filter_selection.dart';

void main() {
  group('HomeSortEnum 随机排序', () {
    test('random 的 officialTag 是 pseudo_rand', () {
      expect(HomeSortEnum.random.officialTag, 'pseudo_rand');
    });

    test('random 出现在默认排序列表里', () {
      expect(
        HomeSortEnum.descriptionMap.values,
        contains(HomeSortEnum.random),
      );
    });
  });

  group('FilterSelection 认证上传者', () {
    test('勾选时 queryParams 带 flag2=1', () {
      final filter = FilterSelection(verifiedUploaders: true);
      expect(filter.queryParams['flag2'], '1');
    });

    test('未勾选时不带 flag2', () {
      final filter = FilterSelection();
      expect(filter.queryParams.containsKey('flag2'), isFalse);
    });

    test('hasSecondaryFilter 与 activeLabels 反映勾选', () {
      final filter = FilterSelection(verifiedUploaders: true);
      expect(filter.hasSecondaryFilter, isTrue);
      expect(filter.activeLabels, contains('认证上传者'));
    });

    test('duplicate / filterEquals / copyWith 传递 verifiedUploaders', () {
      final filter = FilterSelection(verifiedUploaders: true);
      expect(filter.duplicate().verifiedUploaders, isTrue);
      expect(filter.filterEquals(filter.duplicate()), isTrue);
      final cleared = filter.copyWith(verifiedUploaders: false);
      expect(cleared.verifiedUploaders, isFalse);
      expect(filter.filterEquals(cleared), isFalse);
    });
  });
}
