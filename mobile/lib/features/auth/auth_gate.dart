import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mobile/features/auth/auth_service.dart';
import 'package:mobile/features/auth/session_controller.dart';
import 'package:mobile/features/shell/responsive_shell.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key, this.initialTabIndex});

  /// Tab-index hint from a route (e.g. `/challenges`). Falls back to
  /// [SessionController.preferredTabIndex] when null so non-routed callers behave
  /// exactly as before.
  final int? initialTabIndex;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: sessionController,
      builder: (context, _) {
        return StreamBuilder<User?>(
          stream: authService.authChanges(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            final user = snapshot.data;
            final hasAuthenticatedUser = user != null;
            final isGuest = sessionController.isGuest;
            final isGuestContext = isGuest || !hasAuthenticatedUser;

            final authLabel = isGuestContext
                  ? 'Guest mode'
                  : (user.email?.trim().isNotEmpty == true
                        ? user.email!
                        : 'Signed in');
            return ResponsiveShell(
              authLabel: authLabel,
              isGuest: isGuestContext,
              userId: user?.uid,
              showFirstRunAuthPopup: !hasAuthenticatedUser,
              initialTabIndex: initialTabIndex ?? sessionController.preferredTabIndex,
              onLogout: () async {
                sessionController.requestOpenAccount();
                await authService.signOut();
                sessionController.continueAsGuest();
              },
            );
          },
        );
      },
    );
  }
}
