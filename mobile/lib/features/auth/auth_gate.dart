import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mobile/features/auth/auth_service.dart';
import 'package:mobile/features/auth/session_controller.dart';
import 'package:mobile/features/shell/app_shell_page.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});
  static const _accountTabIndex = 2;

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
            return AppShellPage(
              authLabel: authLabel,
              isGuest: isGuestContext,
              showFirstRunAuthPopup: !hasAuthenticatedUser,
              initialTabIndex: sessionController.preferredTabIndex,
              onLogout: () async {
                sessionController.setPreferredTabIndex(_accountTabIndex);
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
