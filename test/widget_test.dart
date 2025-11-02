// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:vt_polyglot/main.dart';
import 'package:vt_polyglot/database_helper.dart';

void main() {
  setUpAll(() async {
    // Initialize Hive for testing
    final tempDir = await getTemporaryDirectory();
    Hive.init(tempDir.path);
    await DatabaseHelper.init();
  });

  tearDownAll(() async {
    await Hive.close();
  });

  testWidgets('App launches and shows home page', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Verify that the home page is shown
    expect(find.text('VT-Polyglot'), findsOneWidget);
  });

  testWidgets('Navigate to Profile page', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    // Tap on Profile button
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();

    // Verify Profile page is shown
    expect(find.text('Profile'), findsOneWidget);
  });

  testWidgets('Navigate to Library page', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    // Tap on Library button
    await tester.tap(find.text('Library'));
    await tester.pumpAndSettle();

    // Verify Library page is shown
    expect(find.text('Library'), findsOneWidget);
  });
}
