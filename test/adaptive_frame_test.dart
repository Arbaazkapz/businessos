import 'package:businessos/ui/widgets/adaptive_frame.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('wide screens keep a centred phone-width column', (tester) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => AdaptiveFrame(child: child!),
        home: const Scaffold(body: SizedBox.expand(key: Key('body'))),
      ),
    );
    expect(tester.getSize(find.byKey(const Key('body'))).width, 600);
  });

  testWidgets('phones are not constrained', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => AdaptiveFrame(child: child!),
        home: const Scaffold(body: SizedBox.expand(key: Key('body'))),
      ),
    );
    expect(tester.getSize(find.byKey(const Key('body'))).width, 400);
  });
}
