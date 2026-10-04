import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:r34_video/page/site/r34_xxx_search_options.dart';
import 'package:r34_video/page/site/r34_xxx_sort_filter_dialog.dart';

void main() {
  group('R34XxxSearchOptions 伪标签拼装', () {
    test('默认选项：isDefault 为 true，只带最新排序', () {
      const options = R34XxxSearchOptions();
      expect(options.isDefault, isTrue);
      expect(options.toTagClauses(), ['sort:id:desc']);
      expect(options.describe(), '最新投稿');
    });

    test('排序：评分/更新/随机', () {
      const score = R34XxxSearchOptions(sort: R34XxxSort.score);
      expect(score.toTagClauses(), ['sort:score:desc']);
      expect(score.describe(), '评分');

      const updated = R34XxxSearchOptions(sort: R34XxxSort.updated);
      expect(updated.toTagClauses(), ['sort:updated_at:desc']);

      const random = R34XxxSearchOptions(sort: R34XxxSort.random);
      expect(random.toTagClauses(), ['sort:random']);
    });

    test('评分下限：>= 与 <= 两种比较符', () {
      const gte = R34XxxSearchOptions(
        minScore: 1000,
        scoreCompare: R34XxxScoreCompare.gte,
      );
      expect(gte.toTagClauses(), ['sort:id:desc', 'score:>=1000']);
      expect(gte.describe(), '最新 ≥ 1000');

      const lte = R34XxxSearchOptions(
        minScore: 500,
        scoreCompare: R34XxxScoreCompare.lte,
      );
      expect(lte.toTagClauses(), ['sort:id:desc', 'score:<=500']);
    });

    test('评级：safe / questionable / explicit', () {
      const safe = R34XxxSearchOptions(rating: R34XxxRating.safe);
      expect(safe.toTagClauses(), ['sort:id:desc', 'rating:safe']);

      const questionable =
          R34XxxSearchOptions(rating: R34XxxRating.questionable);
      expect(questionable.toTagClauses(), ['sort:id:desc', 'rating:questionable']);

      const explicit = R34XxxSearchOptions(rating: R34XxxRating.explicit);
      expect(explicit.toTagClauses(), ['sort:id:desc', 'rating:explicit']);
      expect(explicit.describe(), '最新 explicit');
    });

    test('组合：评分排序 + 下限 + 评级', () {
      const options = R34XxxSearchOptions(
        sort: R34XxxSort.score,
        minScore: 1000,
        rating: R34XxxRating.explicit,
      );
      expect(options.toTagClauses(), [
        'sort:score:desc',
        'score:>=1000',
        'rating:explicit',
      ]);
      expect(options.describe(), '评分 ≥ 1000 explicit');
      expect(options.isDefault, isFalse);
    });

    test('toTagQuery：把已有 tag 与筛选条件拼成完整搜索串', () {
      const options = R34XxxSearchOptions(
        sort: R34XxxSort.score,
        minScore: 1000,
      );
      expect(options.toTagQuery('ada_wong solo'),
          'ada_wong solo sort:score:desc score:>=1000');
      // 无 tag 时只留伪标签。
      expect(options.toTagQuery(''), 'sort:score:desc score:>=1000');
      // 默认选项 + 空 tag = 空串（走接口默认）。
      expect(const R34XxxSearchOptions().toTagQuery(''), isEmpty);
    });

    test('相等性与 copyWith', () {
      const a = R34XxxSearchOptions(sort: R34XxxSort.score, minScore: 100);
      const b = R34XxxSearchOptions(sort: R34XxxSort.score, minScore: 100);
      expect(a, b);

      expect(
        a.copyWith(minScore: 200),
        const R34XxxSearchOptions(sort: R34XxxSort.score, minScore: 200),
      );
      // 默认选项是全 const，可直接 ==。
      expect(const R34XxxSearchOptions(),
          const R34XxxSearchOptions());
    });
  });

  group('R34XxxSortFilterDialog 交互', () {
    testWidgets('完成返回的选项应包含所选的排序/评分/评级', (tester) async {
      R34XxxSearchOptions? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () async {
                    result = await R34XxxSortFilterDialog.show(
                      context,
                      const R34XxxSearchOptions(),
                    );
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('最新').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('评分').last);
      await tester.pumpAndSettle();

      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '1000');
      await tester.pumpAndSettle();

      await tester.tap(find.text('全部').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('explicit').last);
      await tester.pumpAndSettle();

      await tester.tap(find.text('完成'));
      await tester.pumpAndSettle();

      expect(result, isNotNull);
      expect(result!.sort, R34XxxSort.score);
      expect(result!.minScore, 1000);
      expect(result!.rating, R34XxxRating.explicit);
      expect(result!.toTagQuery('ada_wong'),
          'ada_wong sort:score:desc score:>=1000 rating:explicit');
    });

    testWidgets('点重置返回默认选项', (tester) async {
      R34XxxSearchOptions? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () async {
                    result = await R34XxxSortFilterDialog.show(
                      context,
                      const R34XxxSearchOptions(
                        sort: R34XxxSort.score,
                        minScore: 5000,
                        rating: R34XxxRating.explicit,
                      ),
                    );
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // 先改成非默认，再点重置。
      await tester.tap(find.text('重置'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('完成'));
      await tester.pumpAndSettle();

      expect(result, const R34XxxSearchOptions(),
          reason: '重置后应回到默认（最新、无评分下限、全部评级）');
    });

    testWidgets('评分下限填非法数字时点完成不应关闭', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () =>
                      R34XxxSortFilterDialog.show(context, const R34XxxSearchOptions()),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'abc');
      await tester.pumpAndSettle();

      await tester.tap(find.text('完成'));
      await tester.pumpAndSettle();

      expect(find.byType(R34XxxSortFilterDialog), findsOneWidget,
          reason: '非法评分下限应阻止提交并停留在对话框');
      expect(find.text('评分下限需要是 ≥ 0 的数字'), findsOneWidget,
          reason: '应给出提示');
    });
  });
}
