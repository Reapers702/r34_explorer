import 'package:flutter_test/flutter_test.dart';
import 'package:r34_video/repo/entity/r34_search_request.dart';
import 'package:r34_video/repo/r34_search_repo.dart';

/// [R34SearchRepo.buildSearchQuery]（搜索附加条件参数）与联想解析的单元测试。
void main() {
  group('buildSearchQuery 附加条件', () {
    test('纯文本搜索不带附加条件参数', () {
      final query = R34SearchRepo.buildSearchQuery(
        R34SearchRequest(
          keywordType: SearchKeywordType.keyword,
          keyword: 'tifa',
        ),
      );
      expect(query['q'], 'tifa');
      expect(query.containsKey('tag_ids'), isFalse);
      expect(query.containsKey('model_ids'), isFalse);
      expect(query.containsKey('category_ids'), isFalse);
      expect(query.containsKey('temp_skip_items'), isFalse);
    });

    test('tag_ids / category_ids 带 all, 前缀，model_ids 与 blacklist 直接拼接', () {
      final query = R34SearchRepo.buildSearchQuery(
        R34SearchRequest(
          keywordType: SearchKeywordType.keyword,
          keyword: 'tifa',
          tagIds: ['51', '52'],
          artistIds: ['33'],
          categoryIds: ['1', '2'],
          blacklistTokens: ['tag:6', 'cat:7'],
        ),
      );
      expect(query['tag_ids'], 'all,51,52');
      expect(query['model_ids'], '33');
      expect(query['category_ids'], 'all,1,2');
      expect(query['temp_skip_items'], 'tag:6,cat:7');
    });

    test('附加条件只在 keyword 类型生效（分类页不带）', () {
      final query = R34SearchRepo.buildSearchQuery(
        R34SearchRequest(
          keywordType: SearchKeywordType.tag,
          keyword: '5002',
          tagIds: ['51'],
        ),
      );
      expect(query.containsKey('tag_ids'), isFalse);
      expect(query['from'], isNotNull);
    });

    test('keyword 搜索带 from_videos / from_albums 分页参数', () {
      final query = R34SearchRepo.buildSearchQuery(
        R34SearchRequest(
          keywordType: SearchKeywordType.keyword,
          keyword: 'tifa',
          page: 3,
        ),
      );
      expect(query['from_videos'], '03');
      expect(query['from_albums'], '03');
    });

    test('空关键词 + 附加 Tag：q 传空串但条件照下发', () {
      final query = R34SearchRepo.buildSearchQuery(
        R34SearchRequest(
          keywordType: SearchKeywordType.keyword,
          keyword: '',
          tagIds: ['369'],
        ),
      );
      expect(query.containsKey('q'), isTrue);
      expect(query['q'], '');
      expect(query['tag_ids'], 'all,369');
    });

    test('空关键词的 path 是 /search/（站点 data-videosUrl），非空则带 slug', () {
      R34SearchRequest req({required String keyword, List<String> tagIds = const []}) {
        return R34SearchRequest(
          keywordType: SearchKeywordType.keyword,
          keyword: keyword,
          tagIds: tagIds,
        );
      }
      expect(R34SearchRepo.pathOf(req(keyword: '', tagIds: ['369'])), '/search/');
      expect(R34SearchRepo.pathOf(req(keyword: 'tifa')), '/search/tifa/');
      expect(R34SearchRepo.pathOf(req(keyword: 'pi pi')), '/search/pi-pi/');
      expect(R34SearchRepo.pathOf(req(keyword: 'a-b')), '/search/a--b/');
    });
  });

  group('联想 JSON 解析', () {
    test('tags 端点：items[{id,title,total}]', () {
      final items = R34SearchRepo.parseAutocompleteItems('''
        {"total_count":2,"items":[{"id":"51","title":"ada wong (resident evil)","total":"2997"},{"id":"52","title":"tifa","total":"100"}]}
      ''');
      expect(items, hasLength(2));
      expect(items[0].id, '51');
      expect(items[0].title, 'ada wong (resident evil)');
      expect(items[0].total, '2997');
    });

    test('categories / models 端点：id 键回退、title 键回退', () {
      final items = R34SearchRepo.parseAutocompleteItems('''
        {"items":[{"category_id":"3","name":"3D"},{"model_id":"8","title":"tifa lockhart"}]}
      ''');
      expect(items[0].id, '3');
      expect(items[0].title, '3D');
      expect(items[1].id, '8');
      expect(items[1].title, 'tifa lockhart');
    });

    test('items 为空串或缺失时返回空列表', () {
      expect(R34SearchRepo.parseAutocompleteItems('{"items":""}'), isEmpty);
      expect(R34SearchRepo.parseAutocompleteItems('not json'), isEmpty);
      expect(R34SearchRepo.parseAutocompleteItems('{"items":[]}'), isEmpty);
    });
  });

  group('blacklist token', () {
    test('数字 id 才生成 token，非数字丢弃（原站 JS 同款校验）', () {
      expect(R34SearchRepo.toBlacklistToken('tag', '51'), 'tag:51');
      expect(R34SearchRepo.toBlacklistToken('cat', '3'), 'cat:3');
      expect(R34SearchRepo.toBlacklistToken('model', '8'), 'model:8');
      expect(R34SearchRepo.toBlacklistToken('tag', 'abc'), isNull);
      expect(R34SearchRepo.toBlacklistToken('cat', '12a'), isNull);
      expect(R34SearchRepo.toBlacklistToken('model', ''), isNull);
    });
  });
}
