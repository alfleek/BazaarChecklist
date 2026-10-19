import 'package:flutter/material.dart';
import 'package:mobile/features/account/account_page.dart';
import 'package:mobile/features/auth/login_page.dart';
import 'package:mobile/features/build_input/build_input_page.dart';
import 'package:mobile/features/builds/build_list_page.dart';
import 'package:mobile/features/challenges/challenges_page.dart';
import 'package:mobile/features/search/search_page.dart';
import 'package:mobile/features/shared/ui/shell_tab_bar.dart';
import 'package:mobile/features/shell/shell_navigation_intent.dart';

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

class _AppShellPageState extends State<AppShellPage>
    with ShellTabIntentMixin<AppShellPage> {
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

  static const _tabPaths = ['/runs', '/catalog', '/challenges'];

  @override
  void initState() {
    super.initState();
    initShellTabIndex(widget.initialTabIndex);
    maybeShowFirstRunAuthPrompt(
      showFirstRunAuthPopup: widget.showFirstRunAuthPopup,
      openLogin: _openLogin,
    );
    maybeOpenAccountFromSession(
      isGuest: widget.isGuest,
      authLabel: widget.authLabel,
      onLogout: widget.onLogout,
    );
  }

  @override
  void didUpdateWidget(covariant AppShellPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    applyUpdatedTabIndex(widget.initialTabIndex, oldWidget.initialTabIndex);
    if (oldWidget.showFirstRunAuthPopup != widget.showFirstRunAuthPopup) {
      maybeShowFirstRunAuthPrompt(
        showFirstRunAuthPopup: widget.showFirstRunAuthPopup,
        openLogin: _openLogin,
      );
    }
    maybeOpenAccountFromSession(
      isGuest: widget.isGuest,
      authLabel: widget.authLabel,
      onLogout: widget.onLogout,
    );
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
          title: _titles[currentTabIndex],
          subtitle: _tabSubtitles[currentTabIndex],
          icon: _tabIcons[currentTabIndex],
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
          IndexedStack(index: currentTabIndex, children: pages),
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
      floatingActionButton: currentTabIndex == 0
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
              selectedIndex: currentTabIndex,
              onDestinationSelected: (value) {
                selectTab(value, routePath: _tabPaths[value]);
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

}
