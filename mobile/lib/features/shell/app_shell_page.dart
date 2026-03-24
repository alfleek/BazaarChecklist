import 'package:flutter/material.dart';
import 'package:mobile/features/account/account_page.dart';
import 'package:mobile/features/auth/login_page.dart';
import 'package:mobile/features/auth/session_controller.dart';
import 'package:mobile/features/build_input/build_input_page.dart';
import 'package:mobile/features/builds/build_list_page.dart';
import 'package:mobile/features/search/search_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppShellPage extends StatefulWidget {
  const AppShellPage({
    required this.authLabel,
    required this.isGuest,
    required this.showFirstRunAuthPopup,
    super.key,
    this.initialTabIndex,
    this.onLogout,
  });

  final Future<void> Function()? onLogout;
  final String authLabel;
  final bool isGuest;
  final bool showFirstRunAuthPopup;
  final int? initialTabIndex;

  @override
  State<AppShellPage> createState() => _AppShellPageState();
}

class _AppShellPageState extends State<AppShellPage> {
  static const _accountTabIndex = 2;
  int _currentIndex = 0;
  bool _showGuestOnboardingCard = false;
  bool _isFirstRunAuthPromptVisible = false;
  static const _guestOnboardingDismissedKey = 'guest_onboarding_dismissed_v1';
  static const _firstRunAuthChoiceKey = 'first_run_auth_choice_v1';

  static const _titles = ['Runs', 'Catalog', 'Account'];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialTabIndex ?? 0;
    if (widget.initialTabIndex != null) {
      sessionController.clearPreferredTabIndex();
    }
    _loadGuestOnboardingState();
    _maybeShowFirstRunAuthPrompt();
  }

  @override
  void didUpdateWidget(covariant AppShellPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialTabIndex != null &&
        widget.initialTabIndex != oldWidget.initialTabIndex &&
        widget.initialTabIndex != _currentIndex) {
      setState(() => _currentIndex = widget.initialTabIndex!);
      sessionController.clearPreferredTabIndex();
    }
    if (oldWidget.isGuest != widget.isGuest) {
      if (widget.isGuest) {
        _loadGuestOnboardingState();
      } else {
        setState(() => _showGuestOnboardingCard = false);
      }
    }
    if (oldWidget.showFirstRunAuthPopup != widget.showFirstRunAuthPopup) {
      _maybeShowFirstRunAuthPrompt();
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      BuildListPage(
        isGuest: widget.isGuest,
        showOnboardingCard: _showGuestOnboardingCard,
        onDismissOnboardingCard: _dismissGuestOnboardingCard,
        onSignInRequested: _openLogin,
      ),
      const SearchPage(),
      AccountPage(
        isGuest: widget.isGuest,
        authLabel: widget.authLabel,
        onLogout: widget.onLogout,
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: Text(_titles[_currentIndex])),
      body: IndexedStack(index: _currentIndex, children: pages),
      floatingActionButton: _currentIndex == 0
          ? FloatingActionButton.extended(
              onPressed: _openBuildInput,
              icon: const Icon(Icons.add),
              label: const Text('Add run'),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (value) => setState(() => _currentIndex = value),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.view_list_outlined),
            selectedIcon: Icon(Icons.view_list),
            label: 'Runs',
          ),
          NavigationDestination(
            icon: Icon(Icons.tune_outlined),
            selectedIcon: Icon(Icons.tune),
            label: 'Catalog',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Account',
          ),
        ],
      ),
    );
  }

  Future<void> _openBuildInput() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const BuildInputPage()));
  }

  Future<void> _openLogin() async {
    if (mounted) {
      setState(() => _currentIndex = _accountTabIndex);
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const LoginPage(),
        fullscreenDialog: true,
      ),
    );
    if (mounted) {
      setState(() => _currentIndex = _accountTabIndex);
    }
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
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Welcome to BazaarChecklist'),
            content: const Text(
              'Choose how you want to start. Guest mode keeps your data on this device until you sign in.',
            ),
            actions: [
              FilledButton(
                onPressed: () async {
                  final dialogPrefs = await SharedPreferences.getInstance();
                  await dialogPrefs.setBool(_firstRunAuthChoiceKey, true);
                  if (!mounted) return;
                  if (!dialogContext.mounted) return;
                  Navigator.of(dialogContext).pop();
                  await _openLogin();
                },
                child: const Text('Sign in or create account'),
              ),
              OutlinedButton(
                onPressed: () async {
                  final dialogPrefs = await SharedPreferences.getInstance();
                  await dialogPrefs.setBool(_firstRunAuthChoiceKey, true);
                  if (!mounted) return;
                  if (!dialogContext.mounted) return;
                  Navigator.of(dialogContext).pop();
                },
                child: const Text('Continue as guest'),
              ),
            ],
          );
        },
      );
      _isFirstRunAuthPromptVisible = false;
    });
  }

  Future<void> _loadGuestOnboardingState() async {
    final prefs = await SharedPreferences.getInstance();
    final dismissed = prefs.getBool(_guestOnboardingDismissedKey) ?? false;
    if (!mounted) return;
    setState(() {
      _showGuestOnboardingCard = widget.isGuest && !dismissed;
    });
  }

  Future<void> _dismissGuestOnboardingCard() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_guestOnboardingDismissedKey, true);
    if (!mounted) return;
    setState(() => _showGuestOnboardingCard = false);
  }
}
