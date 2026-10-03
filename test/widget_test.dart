import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:r34_video/page/component/common/app_state_view.dart';
import 'package:r34_video/theme/app_theme.dart';

void main() {
  testWidgets('主题与空状态组件可以正常构建', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(
          body: AppStateView.empty(title: '这里什么都没有'),
        ),
      ),
    );

    expect(find.text('这里什么都没有'), findsOneWidget);
  });
}
