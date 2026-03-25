import 'package:flutter/material.dart';
import 'package:mobile/features/account/account_page.dart';
import 'package:mobile/features/auth/login_page.dart';
import 'package:mobile/features/auth/session_controller.dart';
import 'package:mobile/features/build_input/build_input_page.dart';
import 'package:mobile/features/builds/build_list_page.dart';
import 'package:mobile/features/challenges/challenges_page.dart';
import 'package:mobile/features/search/search_page.dart';
import 'package:mobile/features/shared/ui/shell_tab_bar.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppShellPage extends StatefulWidget {
  const AppShellPage({
    required this.authLabel,
    required this.isGuest,
    required this.showFirstRunAuthPopup,
    super.key,
    this.initialTabIndex,
    this.onLogout,
    this.userId,
  });

  final Future<void> Function()? onLogout;
  final String authLabel;
  final bool isGuest;
  /// Firebase Auth uid when signed in; null when guest or unauthenticated.
  final String? userId;
  final bool showFirstRunAuthPopup;
  final int? initialTabIndex;

  @override
  State<AppShellPage> createState() => _AppShellPageState();
}

class _AppShellPageState extends State<AppShellPage> {
  int _currentIndex = 0;
  bool _isFirstRunAuthPromptVisible = false;
  static const _firstRunAuthChoiceKey = 'first_run_auth_choice_v1';

  static const _titles = ['Runs', 'Catalog', 'Challenges'];

  static const _tabSubtitles = [
    'Saved run history',
    'Search and filter',
    'Progress and checklists',
  ];

  static const _tabIcons = <IconData>[
    Icons.emoji_events_rounded,
    Icons.layers_rounded,
    Icons.fact_check_rounded,
  ];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialTabIndex ?? sessionController.shellTabIndex;
    if (widget.initialTabIndex != null) {
      sessionController.clearPreferredTabIndex();
    }
    sessionController.persistShellTabIndex(_currentIndex);
    _maybeShowFirstRunAuthPrompt();
    _maybeOpenAccountFromSession();
  }

  @override
  void didUpdateWidget(covariant AppShellPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialTabIndex != null &&
        widget.initialTabIndex != oldWidget.initialTabIndex &&
        widget.initialTabIndex != _currentIndex) {
      setState(() => _currentIndex = widget.initialTabIndex!);
      sessionController.clearPreferredTabIndex();
    } else if (widget.initialTabIndex != null &&
        widget.initialTabIndex == _currentIndex) {
      // Tab already correct (e.g. Catalog prefill while staying on Catalog).
      sessionController.clearPreferredTabIndex();
    }
    if (oldWidget.showFirstRunAuthPopup != widget.showFirstRunAuthPopup) {
      _maybeShowFirstRunAuthPrompt();
    }
    _maybeOpenAccountFromSession();
  }

  void _maybeOpenAccountFromSession() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!sessionController.takePendingOpenAccount()) return;
      // Replace any stacked routes (e.g. stale guest Account after sign-in) so
      // back does not return to an outdated Account screen.
      Navigator.of(context).pushAndRemoveUntil<void>(
        MaterialPageRoute<void>(
          builder: (_) => AccountPage(
            isGuest: widget.isGuest,
            authLabel: widget.authLabel,
            onLogout: widget.onLogout,
          ),
        ),
        (route) => route.isFirst,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      BuildListPage(
        isGuest: widget.isGuest,
        userId: widget.userId,
      ),
      SearchPage(
        isGuest: widget.isGuest,
        userId: widget.userId,
      ),
      ChallengesPage(
        isGuest: widget.isGuest,
        userId: widget.userId,
      ),
    ];

    return Scaffold(
      extendBody: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        toolbarHeight: 64,
        flexibleSpace: const ShellAppBarFlexibleSpace(),
        title: ShellTabAppBarTitle(
          title: _titles[_currentIndex],
          subtitle: _tabSubtitles[_currentIndex],
          icon: _tabIcons[_currentIndex],
        ),
        actions: [
          IconButton(
            tooltip: 'Account',
            onPressed: () {
              Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => AccountPage(
                    isGuest: widget.isGuest,
                    authLabel: widget.authLabel,
                    onLogout: widget.onLogout,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.person_outline),
          ),
        ],
      ),
      body: Stack(
        children: [
          IndexedStack(index: _currentIndex, children: pages),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 148,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      const Color(0xFF120A0B).withValues(alpha: 0),
                      const Color(0xFF120A0B).withValues(alpha: 0.38),
                      const Color(0xFF120A0B).withValues(alpha: 0.72),
                      const Color(0xFF120A0B).withValues(alpha: 0.94),
                    ],
                    stops: const [0.0, 0.42, 0.76, 1.0],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: _currentIndex == 0
          ? FloatingActionButton(
              onPressed: _openBuildInput,
              child: const Icon(Icons.add),
            )
          : null,
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFF241516),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: const Color(0xFF5B3A1F)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: NavigationBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              height: 80,
              selectedIndex: _currentIndex,
              onDestinationSelected: (value) {
                sessionController.persistShellTabIndex(value);
                setState(() => _currentIndex = value);
              },
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.emoji_events_outlined),
                  selectedIcon: Icon(Icons.emoji_events),
                  label: 'Runs',
                ),
                NavigationDestination(
                  icon: Icon(Icons.layers_outlined),
                  selectedIcon: Icon(Icons.layers),
                  label: 'Catalog',
                ),
                NavigationDestination(
                  icon: Icon(Icons.fact_check_outlined),
                  selectedIcon: Icon(Icons.fact_check),
                  label: 'Challenges',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openBuildInput() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BuildInputPage(
          isGuest: widget.isGuest,
          userId: widget.userId,
        ),
      ),
    );
  }

  Future<void> _openLogin() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const LoginPage(),
        fullscreenDialog: true,
      ),
    );
  }

  Future<void> _maybeShowFirstRunAuthPrompt() async {
    if (!widget.showFirstRunAuthPopup || _isFirstRunAuthPromptVisible) return;
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
          return _FirstRunWelcomeDialog(
            onSignIn: () async {
              final dialogPrefs = await SharedPreferences.getInstance();
              await dialogPrefs.setBool(_firstRunAuthChoiceKey, true);
              if (!mounted) return;
              if (!dialogContext.mounted) return;
              Navigator.of(dialogContext).pop();
              await _openLogin();
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

/// First-launch welcome: short app intro + sign-in vs guest (matches Bazaar theme).
class _FirstRunWelcomeDialog extends StatelessWidget {
  const _FirstRunWelcomeDialog({
    required this.onSignIn,
    required this.onContinueAsGuest,
  });

  final Future<void> Function() onSignIn;
  final Future<void> Function() onContinueAsGuest;

  static const _surface = Color(0xFF1B1112);
  static const _surfaceInner = Color(0xFF241516);
  static const _border = Color(0xFF5B3A1F);
  static const _muted = Color(0xFFC3B5A0);
  static const _accentSoft = Color(0xFFE2B569);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _border, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.45),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: _surfaceInner,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: _border),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Icon(
                          Icons.emoji_events_outlined,
                          size: 28,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Welcome',
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: _accentSoft,
                              letterSpacing: 0.4,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'BazaarChecklist',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                              height: 1.15,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  'Track your winning runs and which items you have won with. '
                  'Browse the catalog to see what you have left to unlock.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFFF5E9D8),
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: _surfaceInner,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _border.withValues(alpha: 0.85)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.cloud_outlined,
                        size: 20,
                        color: theme.colorScheme.primary.withValues(alpha: 0.95),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Sign in to sync across devices. Guest mode keeps '
                          'everything on this phone until you connect an account.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: _muted,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                FilledButton(
                  onPressed: onSignIn,
                  child: const Text('Sign in or create account'),
                ),
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: onContinueAsGuest,
                  child: const Text('Continue as guest'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
