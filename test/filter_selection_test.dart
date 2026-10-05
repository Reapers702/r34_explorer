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

  group('FilterSelection 上传时间自定义档位', () {
    test('custom 档位把 from/to 天数映射为 post_date_from / post_date_to', () {
      final filter = FilterSelection(
        dateAdded: VideoDateAdded.custom,
        customFromDays: 90,
        customToDays: 7,
      );
      expect(filter.queryParams['post_date_from'], '90');
      expect(filter.queryParams['post_date_to'], '7');
    });

    test('非 custom 档位仍只发单向 post_date_from，不发 to', () {
      final filter = FilterSelection(dateAdded: VideoDateAdded.pastWeek);
      expect(filter.queryParams['post_date_from'], '7');
      expect(filter.queryParams.containsKey('post_date_to'), isFalse);
    });

    test('自定义留空一侧不输出对应参数', () {
      final fromOnly = FilterSelection(
        dateAdded: VideoDateAdded.custom,
        customFromDays: 90,
      );
      expect(fromOnly.queryParams['post_date_from'], '90');
      expect(fromOnly.queryParams.containsKey('post_date_to'), isFalse);

      final toOnly = FilterSelection(
        dateAdded: VideoDateAdded.custom,
        customToDays: 7,
      );
      expect(toOnly.queryParams.containsKey('post_date_from'), isFalse);
      expect(toOnly.queryParams['post_date_to'], '7');
    });

    test('duplicate / filterEquals / copyWith 传递自定义天数', () {
      final filter = FilterSelection(
        dateAdded: VideoDateAdded.custom,
        customFromDays: 90,
        customToDays: 7,
      );
      expect(filter.duplicate().customFromDays, 90);
      expect(filter.duplicate().customToDays, 7);
      expect(filter.filterEquals(filter.duplicate()), isTrue);

      final diff = FilterSelection(
        dateAdded: VideoDateAdded.custom,
        customFromDays: 30,
        customToDays: 7,
      );
      expect(filter.filterEquals(diff), isFalse);

      final cleared = filter.copyWith(clearCustomDate: true);
      expect(cleared.customFromDays, isNull);
      expect(cleared.customToDays, isNull);
    });

    test('custom 的 activeLabels 展示天数范围', () {
      final filter = FilterSelection(
        dateAdded: VideoDateAdded.custom,
        customFromDays: 90,
        customToDays: 7,
      );
      expect(filter.activeLabels, contains('90 ~ 7 天前'));
    });
  });
}
