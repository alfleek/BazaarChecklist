import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/features/account/account_page.dart';
import 'package:mobile/features/auth/session_controller.dart';
import 'package:mobile/features/shared/ui/first_run_welcome_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Single owner of cross-flow tab/account navigation intent, shared by every shell
/// (mobile [AppShellPage], web `WebShellPage`) so none of them duplicates the
/// "apply preferred tab once, then clear" / "open Account once pending" contract
/// described in docs/AI_CODING.md's "Navigation intent ownership" section.
mixin ShellTabIntentMixin<T extends StatefulWidget> on State<T> {
  int currentTabIndex = 0;
  bool _isFirstRunAuthPromptVisible = false;
  static const _firstRunAuthChoiceKey = 'first_run_auth_choice_v1';

  /// Call from [State.initState]. Resolves the starting tab from a route-provided
  /// hint (`initialTabIndex`) or the last persisted shell tab, then clears the
  /// session's preferred-tab intent once consumed.
  void initShellTabIndex(int? initialTabIndex) {
    currentTabIndex = initialTabIndex ?? sessionController.shellTabIndex;
    if (initialTabIndex != null) {
      sessionController.clearPreferredTabIndex();
    }
    sessionController.persistShellTabIndex(currentTabIndex);
  }

  /// Call from [State.didUpdateWidget] with the current and previous
  /// `initialTabIndex` whenever it may have changed (e.g. a Challenges -> Catalog
  /// prefill jump while this shell is already mounted).
  void applyUpdatedTabIndex(int? initialTabIndex, int? oldInitialTabIndex) {
    if (initialTabIndex != null &&
        initialTabIndex != oldInitialTabIndex &&
        initialTabIndex != currentTabIndex) {
      setState(() => currentTabIndex = initialTabIndex);
      sessionController.clearPreferredTabIndex();
    } else if (initialTabIndex != null && initialTabIndex == currentTabIndex) {
      // Tab already correct (e.g. Catalog prefill while staying on Catalog).
      sessionController.clearPreferredTabIndex();
    }
  }

  /// Updates the visible tab, persists it for shell-remount survival, and (when a
  /// route exists, e.g. on web) updates the URL to match.
  void selectTab(int index, {String? routePath}) {
    sessionController.persistShellTabIndex(index);
    setState(() => currentTabIndex = index);
    if (routePath != null) {
      GoRouter.maybeOf(context)?.go(routePath);
    }
  }

  /// Call from both [State.initState] and [State.didUpdateWidget]. Opens Account as
  /// a pushed route (not a tab) when [SessionController.requestOpenAccount] has a
  /// pending request, replacing any stacked routes so back doesn't return to a stale
  /// Account screen (e.g. a guest Account screen left over after sign-in).
  void maybeOpenAccountFromSession({
    required bool isGuest,
    required String authLabel,
    required Future<void> Function()? onLogout,
  }) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!sessionController.takePendingOpenAccount()) return;
      Navigator.of(context).pushAndRemoveUntil<void>(
        MaterialPageRoute<void>(
          builder: (_) => AccountPage(
            isGuest: isGuest,
            authLabel: authLabel,
            onLogout: onLogout,
          ),
        ),
        (route) => route.isFirst,
      );
    });
  }

  /// Call from both [State.initState] and [State.didUpdateWidget] (when
  /// `showFirstRunAuthPopup` may have changed). Shows [FirstRunWelcomeDialog] once
  /// per device until the user picks sign-in or guest.
  Future<void> maybeShowFirstRunAuthPrompt({
    required bool showFirstRunAuthPopup,
    required Future<void> Function() openLogin,
  }) async {
    if (!showFirstRunAuthPopup || _isFirstRunAuthPromptVisible) return;
    final prefs = await SharedPreferences.getInstance();
    final hasChosenAuthFlow = prefs.getBool(_firstRunAuthChoiceKey) ?? false;
    if (hasChosenAuthFlow || !mounted) return;

    _isFirstRunAuthPromptVisible = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        barrierColor: Colors.black54,
        builder: (dialogContext) {
          return FirstRunWelcomeDialog(
            onSignIn: () async {
              final dialogPrefs = await SharedPreferences.getInstance();
              await dialogPrefs.setBool(_firstRunAuthChoiceKey, true);
              if (!mounted) return;
              if (!dialogContext.mounted) return;
              Navigator.of(dialogContext).pop();
              await openLogin();
            },
            onContinueAsGuest: () async {
              final dialogPrefs = await SharedPreferences.getInstance();
              await dialogPrefs.setBool(_firstRunAuthChoiceKey, true);
              if (!mounted) return;
              if (!dialogContext.mounted) return;
              Navigator.of(dialogContext).pop();
            },
          );
        },
      );
      _isFirstRunAuthPromptVisible = false;
    });
  }
}
