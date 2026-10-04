import 'package:flutter_test/flutter_test.dart';
import 'package:r34_video/repo/entity/r34_search_request.dart';

/// [R34SearchRequest] 附加条件（tag_ids / model_ids / category_ids /
/// temp_skip_items）的单元测试。
void main() {
  group('R34SearchRequest 附加条件', () {
    test('默认无附加条件', () {
      final request = R34SearchRequest(
        keywordType: SearchKeywordType.keyword,
        keyword: 'tifa',
      );
      expect(request.tagIds, isEmpty);
      expect(request.artistIds, isEmpty);
      expect(request.categoryIds, isEmpty);
      expect(request.blacklistTokens, isEmpty);
    });

    test('构造时传入并保持', () {
      final request = R34SearchRequest(
        keywordType: SearchKeywordType.keyword,
        keyword: 'tifa',
        tagIds: ['1', '2'],
        artistIds: ['3'],
        categoryIds: ['4', '5'],
        blacklistTokens: ['tag:6', 'model:7'],
      );
      expect(request.tagIds, ['1', '2']);
      expect(request.artistIds, ['3']);
      expect(request.categoryIds, ['4', '5']);
      expect(request.blacklistTokens, ['tag:6', 'model:7']);
    });

    test('duplicate 拷贝附加条件', () {
      final request = R34SearchRequest(
        keywordType: SearchKeywordType.keyword,
        keyword: 'tifa',
        tagIds: ['1'],
        artistIds: ['2'],
        categoryIds: ['3'],
        blacklistTokens: ['tag:4'],
      );
      final copy = request.duplicate();
      expect(copy.tagIds, ['1']);
      expect(copy.artistIds, ['2']);
      expect(copy.categoryIds, ['3']);
      expect(copy.blacklistTokens, ['tag:4']);
    });

    test('equals 比较附加条件', () {
      R34SearchRequest build({List<String>? tagIds}) {
        return R34SearchRequest(
          keywordType: SearchKeywordType.keyword,
          keyword: 'tifa',
          tagIds: tagIds ?? ['1'],
          artistIds: ['2'],
          categoryIds: ['3'],
          blacklistTokens: ['tag:4'],
        );
      }

      expect(build().equals(build()), isTrue);
      expect(build(tagIds: ['9']).equals(build()), isFalse);
      final diffBlacklist = R34SearchRequest(
        keywordType: SearchKeywordType.keyword,
        keyword: 'tifa',
        tagIds: ['1'],
        artistIds: ['2'],
        categoryIds: ['3'],
        blacklistTokens: ['tag:9'],
      );
      expect(diffBlacklist.equals(build()), isFalse);
    });

    test('toJson 包含附加条件', () {
      final request = R34SearchRequest(
        keywordType: SearchKeywordType.keyword,
        keyword: 'tifa',
        tagIds: ['1'],
        artistIds: ['2'],
        categoryIds: ['3'],
        blacklistTokens: ['tag:4'],
      );
      final json = request.toJson();
      expect(json['tagIds'], ['1']);
      expect(json['artistIds'], ['2']);
      expect(json['categoryIds'], ['3']);
      expect(json['blacklistTokens'], ['tag:4']);
    });
  });
}
