import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:mobile/features/auth/login_page.dart';
import 'package:mobile/features/auth/session_controller.dart';
import 'package:mobile/features/runs/runs_repository.dart';
import 'package:mobile/features/shell/app_shell_page.dart';
import 'package:mobile/features/shared/ui/section_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    resetGuestRunsRepositoryForTest();
    sessionController.persistShellTabIndex(0);
  });

  testWidgets('section card renders title and child content', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SectionCard(title: 'Runs', child: Text('Card content')),
        ),
      ),
    );

    expect(find.text('Runs'), findsOneWidget);
    expect(find.text('Card content'), findsOneWidget);
  });

  testWidgets('first-run auth popup appears once', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AppShellPage(
          authLabel: 'Guest mode',
          isGuest: true,
          showFirstRunAuthPopup: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Welcome'), findsOneWidget);
    expect(find.text('BazaarChecklist'), findsOneWidget);
    expect(find.text('Continue as guest'), findsOneWidget);
    expect(find.text('Sign in or create account'), findsOneWidget);

    await tester.tap(find.text('Continue as guest'));
    await tester.pumpAndSettle();

    expect(find.byType(Dialog), findsNothing);
  });

  testWidgets('login mode toggle updates primary CTA', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: LoginPage()));
    await tester.pumpAndSettle();

    expect(find.text('Sign in'), findsWidgets);
    expect(find.text('Forgot password?'), findsOneWidget);

    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();

    expect(find.text('Create account'), findsWidgets);
    expect(find.text('Forgot password?'), findsNothing);
  });

  testWidgets('app shell applies updated initial tab intent to challenges', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AppShellPage(
          authLabel: 'Guest mode',
          isGuest: true,
          showFirstRunAuthPopup: false,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: find.byType(AppBar), matching: find.text('Runs')),
      findsOneWidget,
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: AppShellPage(
          authLabel: 'Signed in',
          isGuest: false,
          showFirstRunAuthPopup: false,
          initialTabIndex: 2,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.descendant(of: find.byType(AppBar), matching: find.text('Challenges')),
      findsOneWidget,
    );
  });
}
