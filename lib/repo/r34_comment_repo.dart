import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as parser;
import 'package:r34_video/repo/r34_client.dart';
import 'package:r34_video/util/http_trace_util.dart';

class R34Comment {
  final String authorName;
  final String? avatarUrl;
  final String content;

  /// `1 year ago` 这类相对时间，站点直接给文本。
  final String timeText;

  const R34Comment({
    required this.authorName,
    required this.content,
    this.avatarUrl,
    this.timeText = '',
  });
}

/// 视频评论。
///
/// 站点的评论是前端脚本注入的，不在初始 HTML 里，所以这里做了几手准备：
/// 依次尝试几种常见容器/条目结构，一种都匹配不上就返回空列表，
/// 由 UI 展示「暂无评论」，而不是把整页搞崩。
class R34CommentRepo {
  /// 评论条目候选选择器（按优先级）。
  static const List<String> _itemSelectors = [
    'div.comment_item',
    'div.comment-item',
    'li.comment_item',
    'div.comments_list div.comment',
    '#tab_comments div.comment',
    'div[data-comment-id]',
  ];

  static const List<String> _authorSelectors = [
    'span.username',
    '.username',
    '.comment_author',
    '.author',
    'a.user',
  ];

  static const List<String> _contentSelectors = [
    'div.comment_text',
    '.comment_text',
    '.comment-text',
    '.comment_body',
    '.text',
    'p',
  ];

  static const List<String> _timeSelectors = [
    '.comment_date',
    '.date',
    'time',
    '.added',
  ];

  static Future<List<R34Comment>> getComments(String detailUrl) async {
    try {
      final res = await R34Client.instance.get(Uri.parse(detailUrl));
      if (res.statusCode != 200) {
        HttpTraceUtil.handleHttpError(res.statusCode);
        return const [];
      }
      return parseComments(parser.parse(res.body));
    } catch (e, st) {
      HttpTraceUtil.handleConnectionError(e, st: st);
      return const [];
    }
  }

  static List<R34Comment> parseComments(dom.Document doc) {
    for (final selector in _itemSelectors) {
      final elements = doc.querySelectorAll(selector);
      if (elements.isEmpty) {
        continue;
      }

      final comments = <R34Comment>[];
      for (final element in elements) {
        final content =
            _textOf(element, _contentSelectors).replaceAll(RegExp(r'\s+'), ' ').trim();
        if (content.isEmpty) {
          continue;
        }
        comments.add(
          R34Comment(
            authorName: _textOf(element, _authorSelectors).trim(),
            avatarUrl: element.querySelector('img')?.attributes['src'],
            content: content,
            timeText: _textOf(element, _timeSelectors).trim(),
          ),
        );
      }

      if (comments.isNotEmpty) {
        return comments;
      }
    }
    return const [];
  }

  static String _textOf(dom.Element element, List<String> selectors) {
    for (final selector in selectors) {
      final found = element.querySelector(selector);
      final text = found?.text;
      if (text != null && text.trim().isNotEmpty) {
        return text;
      }
    }
    return '';
  }
}
