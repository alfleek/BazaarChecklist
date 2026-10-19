import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/auth/session_controller.dart';
import 'package:mobile/features/shell/app_shell_page.dart';
import 'package:mobile/features/shell/responsive_shell.dart';
import 'package:mobile/features/shell/web_shell_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    sessionController.persistShellTabIndex(0);
  });

  Future<void> pumpAt(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: ResponsiveShell(
          authLabel: 'Guest mode',
          isGuest: true,
          showFirstRunAuthPopup: false,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('picks AppShellPage below the web breakpoint', (tester) async {
    await pumpAt(tester, const Size(800, 1200));

    expect(find.byType(AppShellPage), findsOneWidget);
    expect(find.byType(WebShellPage), findsNothing);
  });

  testWidgets('picks WebShellPage at or above the web breakpoint', (
    tester,
  ) async {
    await pumpAt(
      tester,
      Size(ResponsiveShell.webBreakpoint, 800),
    );

    expect(find.byType(WebShellPage), findsOneWidget);
    expect(find.byType(AppShellPage), findsNothing);
  });

  testWidgets('WebShellPage applies updated initial tab intent', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: ResponsiveShell(
          authLabel: 'Guest mode',
          isGuest: true,
          showFirstRunAuthPopup: false,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Runs'), findsWidgets);

    await tester.pumpWidget(
      const MaterialApp(
        home: ResponsiveShell(
          authLabel: 'Signed in',
          isGuest: false,
          showFirstRunAuthPopup: false,
          initialTabIndex: 2,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Challenges'), findsWidgets);
  });
}
