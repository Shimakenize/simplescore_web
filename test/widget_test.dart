// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:simplescore_web/main.dart';

void main() {
  testWidgets('Setup screen smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const SimpleScoreWebApp());

    expect(find.text('設定画面'), findsOneWidget);
    expect(find.text('My Teams'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Team A'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Team B'), findsOneWidget);
  });
}
