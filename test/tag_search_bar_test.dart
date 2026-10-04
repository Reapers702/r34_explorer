import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:r34_video/page/component/common/tag_search_bar.dart';

void main() {
  testWidgets('点击联想条目：应回调 onChanged 且输入框不失焦', (tester) async {
    String? changed;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              TagSearchBar(
                selectedTags: const [],
                onChanged: (v) => changed = v,
                rules: TagRules.rule34xxx,
                searchTags: (q) async =>
                    const [TagSuggestion(value: 'ada_wong')],
              ),
            ],
          ),
        ),
      ),
    );

    final textField = find.byType(TextField);
    expect(textField, findsOneWidget);

    // 聚焦输入框。
    await tester.tap(textField);
    await tester.pump();

    // 输入触发联想（debounce 320ms）。
    await tester.enterText(textField, 'ada');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();

    // 联想条目出现。
    expect(find.text('ada wong'), findsOneWidget,
        reason: '输入 ada 后应弹出联想条目');

    // 点击联想条目。
    await tester.tap(find.text('ada wong'));
    await tester.pump();

    // onChanged 应被调用（证明 onTap 完整执行，没有因失焦/卸载而丢失）。
    expect(changed, 'ada_wong', reason: '点击联想条目应把 tag 加入待提交区');

    // 输入框焦点不应丢失。
    final editable =
        tester.state<EditableTextState>(find.byType(EditableText));
    expect(editable.widget.focusNode.hasFocus, isTrue,
        reason: '点击联想条目不应让输入框失焦');
  });

  testWidgets('点击输入框外部空白：焦点应保留（onTapOutside 不禁用则会被夺走）',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              TagSearchBar(
                selectedTags: const [],
                onChanged: (_) {},
                rules: TagRules.rule34xxx,
                searchTags: (q) async => const [],
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );

    final textField = find.byType(TextField);
    await tester.tap(textField);
    await tester.pump();
    expect(
      tester.state<EditableTextState>(find.byType(EditableText)).widget.focusNode
          .hasFocus,
      isTrue,
      reason: '前置：输入框已聚焦',
    );

    // 点击输入框下方的空白区域（联想条目的位置就在输入框外部）。
    await tester.tapAt(tester.getBottomLeft(textField) + const Offset(20, 60));
    await tester.pump();

    expect(
      tester.state<EditableTextState>(find.byType(EditableText)).widget.focusNode
          .hasFocus,
      isTrue,
      reason: '点击输入框外部不应触发默认 unfocus（否则点击联想条目会先失焦、onTap 丢失）',
    );
  });
}
