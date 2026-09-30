import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:businessos/ui/screens/calculator_screen.dart';
import 'package:businessos/core/formatters.dart';

void main() {
  testWidgets('calculator fits a small phone and shows correct result', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(home: CalculatorScreen()));
    await tester.tap(find.text('2'));
    await tester.tap(find.text('+'));
    await tester.tap(find.text('3'));
    await tester.tap(find.text('='));
    await tester.pump();
    expect(find.text('5'), findsNWidgets(2)); // result and digit key
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Tax'));
    await tester.pumpAndSettle();
    expect(find.text('Tax calculator'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('tax cents stay consistent and invalid amounts show an error',
      (tester) async {
    final currency = AppFormatters.currencyCode;
    AppFormatters.currencyCode = 'INR';
    addTearDown(() => AppFormatters.currencyCode = currency);
    await tester.pumpWidget(const MaterialApp(home: CalculatorScreen()));
    await tester.tap(find.text('Tax'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '0.05');
    await tester.pump();
    expect(find.text('₹0.01'), findsNWidgets(2)); // Tax and CGST.
    expect(find.text('₹0.00'), findsOneWidget); // SGST is the remainder.
    expect(find.text('₹0.06'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, '-1');
    await tester.pump();
    expect(find.text('Enter an amount from 0 to 1 trillion.'), findsOneWidget);
    expect(find.text('₹0.06'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
