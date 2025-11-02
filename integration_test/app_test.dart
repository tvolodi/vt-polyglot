import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:vt_polyglot/main.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('end-to-end test', () {
    testWidgets('Navigate to Profile page', (tester) async {
      await tester.pumpWidget(const MyApp());

      // Wait for the app to load
      await tester.pumpAndSettle();

      // Find the Profile button
      final profileButton = find.text('Profile');
      expect(profileButton, findsOneWidget);

      // Tap the Profile button
      await tester.tap(profileButton);
      await tester.pumpAndSettle();

      // Verify we're on the Profile page
      expect(find.text('My Settings'), findsOneWidget);
    });

    testWidgets('Navigate to Library page', (tester) async {
      await tester.pumpWidget(const MyApp());

      // Wait for the app to load
      await tester.pumpAndSettle();

      // Find the Library button
      final libraryButton = find.text('Library');
      expect(libraryButton, findsOneWidget);

      // Tap the Library button
      await tester.tap(libraryButton);
      await tester.pumpAndSettle();

      // Verify we're on the Library page
      expect(find.text('Library'), findsOneWidget);
      expect(find.text('Add New'), findsOneWidget);
    });

    testWidgets('Add a new story to Library', (tester) async {
      await tester.pumpWidget(const MyApp());

      // Navigate to Library
      await tester.pumpAndSettle();
      await tester.tap(find.text('Library'));
      await tester.pumpAndSettle();

      // Tap Add New
      await tester.tap(find.text('Add New'));
      await tester.pumpAndSettle();

      // Fill the form
      await tester.enterText(find.byType(TextField).at(0), 'Test Author');
      await tester.enterText(find.byType(TextField).at(1), 'Test Story');
      await tester.enterText(find.byType(TextField).at(2), 'English');
      await tester.enterText(find.byType(TextField).at(3), 'Adventure');
      await tester.enterText(find.byType(TextField).at(4), 'http://example.com');
      await tester.enterText(find.byType(TextField).at(5), 'This is a test story content.');

      // Tap Add
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();

      // Verify the story is added (check if it appears in the list)
      expect(find.text('Test Story'), findsOneWidget);
    });

    testWidgets('Search in Library', (tester) async {
      await tester.pumpWidget(const MyApp());

      // Navigate to Library
      await tester.pumpAndSettle();
      await tester.tap(find.text('Library'));
      await tester.pumpAndSettle();

      // Enter search query
      await tester.enterText(find.byType(TextField).first, 'Test');
      await tester.pumpAndSettle();

      // Check if filtered results appear
      // Assuming there's a story with 'Test' in it
      expect(find.text('Test Story'), findsOneWidget);
    });
  });
}