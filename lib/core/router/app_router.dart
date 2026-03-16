import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/login_page.dart';
import '../../features/home/home_page.dart';
import '../../features/listing/listing_detail_page.dart';
import '../../features/wishlist/wishlist_page.dart';
import '../providers/auth_provider.dart';
import '../providers/workflow_provider.dart';
import '../widgets/app_bottom_nav.dart';
import '../../features/trade/presentation/trade_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/login',
    redirect: (context, state) {
      final isLoggedIn = ref.read(authProvider);
      final onLogin = state.matchedLocation == '/login';

      if (!isLoggedIn && !onLogin) return '/login';
      if (isLoggedIn && onLogin) return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
      GoRoute(path: '/home', builder: (context, state) => const HomePage()),
      GoRoute(
        path: '/wishlist',
        builder: (context, state) => WishlistPage(
          workflowController: ref.read(workflowControllerProvider),
        ),
      ),
      GoRoute(
        path: '/listing/:listingId',
        builder: (context, state) =>
            ListingDetailPage(listingId: state.pathParameters['listingId']!),
      ),
      GoRoute(
        path: '/create',
        builder: (context, state) =>
            const _PlaceholderPage(title: 'Create Listing', route: '/create'),
      ),
      GoRoute(
        path: '/trades',
        builder: (context, state) => const TradeScreen(),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) =>
            const _PlaceholderPage(title: 'Profile', route: '/profile'),
      ),
    ],
  );
});

class _PlaceholderPage extends StatelessWidget {
  const _PlaceholderPage({required this.title, required this.route});

  final String title;
  final String route;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      bottomNavigationBar: AppBottomNav(currentRoute: route),
      body: Center(
        child: Text(
          '$title page is not ported yet.',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
