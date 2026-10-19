import 'package:flutter/material.dart';
import 'package:mobile/features/shell/app_shell_page.dart';
import 'package:mobile/features/shell/web_shell_page.dart';

/// Picks the mobile shell ([AppShellPage], unchanged) vs. the web shell
/// ([WebShellPage]) based on a width breakpoint, not `kIsWeb` — a wide tablet should
/// get the web-style shell and a narrow desktop browser window should still get the
/// mobile-style shell. See docs/ARCHITECTURE.md "Web vs mobile" for the rationale.
class ResponsiveShell extends StatelessWidget {
  const ResponsiveShell({
    required this.authLabel,
    required this.isGuest,
    required this.showFirstRunAuthPopup,
    super.key,
    this.initialTabIndex,
    this.onLogout,
    this.userId,
  });

  static const double webBreakpoint = 900;

  final Future<void> Function()? onLogout;
  final String authLabel;
  final bool isGuest;
  final String? userId;
  final bool showFirstRunAuthPopup;
  final int? initialTabIndex;

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= webBreakpoint;
    return isWide
        ? WebShellPage(
            authLabel: authLabel,
            isGuest: isGuest,
            showFirstRunAuthPopup: showFirstRunAuthPopup,
            initialTabIndex: initialTabIndex,
            onLogout: onLogout,
            userId: userId,
          )
        : AppShellPage(
            authLabel: authLabel,
            isGuest: isGuest,
            showFirstRunAuthPopup: showFirstRunAuthPopup,
            initialTabIndex: initialTabIndex,
            onLogout: onLogout,
            userId: userId,
          );
  }
}
