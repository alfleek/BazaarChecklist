import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/features/auth/auth_gate.dart';
import 'package:mobile/features/auth/login_page.dart';
import 'package:mobile/features/auth/session_controller.dart';
import 'package:mobile/features/catalog/catalog_item.dart';
import 'package:mobile/features/catalog/catalog_item_detail_page.dart';
import 'package:mobile/features/catalog/catalog_repository.dart';

/// Route table for the web build's shareable/bookmarkable URLs. Tab routes hand a
/// tab-index hint to [AuthGate], which forwards it to whichever shell
/// [ResponsiveShell] picks (see docs/ARCHITECTURE.md "Routing"). Auth gating stays a
/// widget wrapper, not a redirect, since guests already reach every tab today.
final GoRouter appRouter = GoRouter(
  routes: [
    GoRoute(path: '/', redirect: (_, _) => '/runs'),
    GoRoute(
      path: '/runs',
      builder: (context, state) => const AuthGate(initialTabIndex: 0),
    ),
    GoRoute(
      path: '/catalog',
      builder: (context, state) => const AuthGate(initialTabIndex: 1),
    ),
    GoRoute(
      path: '/catalog/:itemId',
      builder: (context, state) =>
          CatalogItemDeepLinkPage(itemId: state.pathParameters['itemId']!),
    ),
    GoRoute(
      path: '/challenges',
      builder: (context, state) => const AuthGate(initialTabIndex: 2),
    ),
    GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
    GoRoute(
      path: '/account',
      builder: (context, state) {
        sessionController.requestOpenAccount();
        return const AuthGate();
      },
    ),
  ],
);

/// Loads a single catalog item by id for a cold-loaded `/catalog/:itemId` link.
/// Unlike in-app navigation from Search, win-stat highlighting (`stats`,
/// `qualifiedRunCount`, `winFilterActive`) isn't available here, so the detail page
/// falls back to its defaults.
class CatalogItemDeepLinkPage extends StatelessWidget {
  const CatalogItemDeepLinkPage({super.key, required this.itemId});

  final String itemId;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<CatalogItem?>(
      future: catalogRepository.fetchCatalogItemById(itemId),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final item = snapshot.data;
        if (item == null) {
          return const Scaffold(body: Center(child: Text('Item not found.')));
        }
        return CatalogItemDetailPage(item: item);
      },
    );
  }
}
