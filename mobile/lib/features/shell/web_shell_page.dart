import 'package:flutter/material.dart';
import 'package:mobile/features/account/account_page.dart';
import 'package:mobile/features/auth/login_page.dart';
import 'package:mobile/features/build_input/build_input_page.dart';
import 'package:mobile/features/builds/build_list_page.dart';
import 'package:mobile/features/challenges/challenges_page.dart';
import 'package:mobile/features/search/search_page.dart';
import 'package:mobile/features/shell/shell_navigation_intent.dart';

/// Web-conventional shell for wide viewports: persistent left navigation rail
/// instead of mobile's bottom NavigationBar + FAB. Wraps the exact same content
/// widgets as [AppShellPage] (BuildListPage/SearchPage/ChallengesPage/AccountPage/
/// LoginPage/BuildInputPage) — only the navigation chrome differs. Picked by
/// `ResponsiveShell` at a width breakpoint; see docs/ARCHITECTURE.md "Web vs mobile".
class WebShellPage extends StatefulWidget {
  const WebShellPage({
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
  State<WebShellPage> createState() => _WebShellPageState();
}

class _WebShellPageState extends State<WebShellPage>
    with ShellTabIntentMixin<WebShellPage> {
  static const _titles = ['Runs', 'Catalog', 'Challenges'];

  static const _tabPaths = ['/runs', '/catalog', '/challenges'];

  static const _surface = Color(0xFF1B1112);
  static const _railBackground = Color(0xFF181011);
  static const _border = Color(0xFF5B3A1F);
  static const _accent = Color(0xFFF0A223);
  static const _muted = Color(0xFFC3B5A0);

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
  void didUpdateWidget(covariant WebShellPage oldWidget) {
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
      BuildListPage(isGuest: widget.isGuest, userId: widget.userId),
      SearchPage(isGuest: widget.isGuest, userId: widget.userId),
      ChallengesPage(isGuest: widget.isGuest, userId: widget.userId),
    ];

    return Scaffold(
      body: Row(
        children: [
          _NavRail(
            selectedIndex: currentTabIndex,
            authLabel: widget.authLabel,
            onDestinationSelected: (index) =>
                selectTab(index, routePath: _tabPaths[index]),
            onAddRun: _openBuildInput,
            onAccount: _openAccount,
          ),
          Expanded(
            child: ColoredBox(
              color: const Color(0xFF120A0B),
              child: SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(32, 28, 32, 12),
                      child: Text(
                        _titles[currentTabIndex],
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1100),
                          child: IndexedStack(
                            index: currentTabIndex,
                            children: pages,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openBuildInput() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            BuildInputPage(isGuest: widget.isGuest, userId: widget.userId),
      ),
    );
  }

  void _openAccount() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => AccountPage(
          isGuest: widget.isGuest,
          authLabel: widget.authLabel,
          onLogout: widget.onLogout,
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

/// Persistent left navigation rail: branding header, tab destinations, "Add run",
/// and account/sign-in status at the bottom.
class _NavRail extends StatelessWidget {
  const _NavRail({
    required this.selectedIndex,
    required this.authLabel,
    required this.onDestinationSelected,
    required this.onAddRun,
    required this.onAccount,
  });

  final int selectedIndex;
  final String authLabel;
  final ValueChanged<int> onDestinationSelected;
  final VoidCallback onAddRun;
  final VoidCallback onAccount;

  static const _destinations = [
    (icon: Icons.emoji_events_outlined, selectedIcon: Icons.emoji_events, label: 'Runs'),
    (icon: Icons.layers_outlined, selectedIcon: Icons.layers, label: 'Catalog'),
    (icon: Icons.fact_check_outlined, selectedIcon: Icons.fact_check, label: 'Challenges'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 248,
      decoration: const BoxDecoration(
        color: _WebShellPageState._railBackground,
        border: Border(right: BorderSide(color: _WebShellPageState._border)),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              child: Row(
                children: [
                  const Icon(
                    Icons.emoji_events_rounded,
                    color: _WebShellPageState._accent,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'BazaarChecklist',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: FilledButton.icon(
                onPressed: onAddRun,
                icon: const Icon(Icons.add),
                label: const Text('Add run'),
              ),
            ),
            const SizedBox(height: 16),
            for (var i = 0; i < _destinations.length; i++)
              _RailDestination(
                icon: selectedIndex == i
                    ? _destinations[i].selectedIcon
                    : _destinations[i].icon,
                label: _destinations[i].label,
                selected: selectedIndex == i,
                onTap: () => onDestinationSelected(i),
              ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
              child: OutlinedButton.icon(
                onPressed: onAccount,
                icon: const Icon(Icons.person_outline),
                label: Text(
                  authLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _WebShellPageState._muted,
                  alignment: Alignment.centerLeft,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RailDestination extends StatelessWidget {
  const _RailDestination({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: Material(
        color: selected
            ? _WebShellPageState._surface
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: selected
                      ? _WebShellPageState._accent
                      : _WebShellPageState._muted,
                ),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? Colors.white : _WebShellPageState._muted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
