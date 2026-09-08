import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:synlen/src/features/reader/presentation/widgets/reader_shell.dart';

void main() {
  testWidgets('应用系统 UI 样式并渲染子树', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ReaderShell(
          overlayStyle: SystemUiOverlayStyle.light,
          canPop: true,
          onPopInvoked: (_) {},
          child: const Text('内容'),
        ),
      ),
    );

    expect(find.text('内容'), findsOneWidget);
    final region = tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(
      find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
    );
    expect(region.value, SystemUiOverlayStyle.light);
  });

  testWidgets('canPop 为 false 时拦截返回并回调', (tester) async {
    var pops = <bool>[];
    await tester.pumpWidget(
      MaterialApp(
        home: ReaderShell(
          overlayStyle: SystemUiOverlayStyle.dark,
          canPop: false,
          onPopInvoked: pops.add,
          child: const Text('内容'),
        ),
      ),
    );

    expect(find.text('内容'), findsOneWidget);
    expect(pops, isEmpty);
  });
}
