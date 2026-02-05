import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart'; // REQUIRED for mocking
import 'package:minecraft_save_creator/main.dart';

void main() {
  testWidgets('App renders Main UI', (WidgetTester tester) async {
    // 1. Setup mock values for SharedPreferences
    // This prevents the "MissingPluginException" or "Null" errors in tests.
    SharedPreferences.setMockInitialValues({
      'accountId': '1234567890123456789', // Optional: Initial test data
      'themeMode': 0,
    });

    // 2. Obtain the mock instance to pass to the app
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    // 3. Build our app and pass the required 'prefs' argument
    await tester.pumpWidget(Ps4ToolApp(prefs: prefs));

    // 4. Wait for animations and initialization to settle
    await tester.pumpAndSettle();

    // 5. Verify that the "World Prep" tab is visible
    expect(find.text('World Prep'), findsOneWidget);

    // 6. Verify Action Tiles are present
    // Adjust these strings if you changed the titles in your UI code
    expect(find.textContaining('Target Folder'), findsOneWidget);
    expect(find.textContaining('Custom World'), findsOneWidget);
  });
}