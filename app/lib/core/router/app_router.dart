import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/command/command_center_page.dart';
import '../../features/auth/login_page.dart';
import '../../features/home/home_page.dart';
import '../../features/listing/create_listing_page.dart';
import '../../features/listing/listing_detail_page.dart';
import '../../features/wishlist/wishlist_page.dart';
import '../providers/auth_provider.dart';
import '../providers/workflow_provider.dart';
import '../../features/trade/presentation/trade_screen.dart';
import '../../features/trade/presentation/verify_handshake_screen.dart';
import '../../features/trade/models/display_trade.dart';
import '../../features/profile/profile_page.dart';

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
        builder: (context, state) => const CreateListingPage(),
      ),
      GoRoute(
        path: '/trades',
        builder: (context, state) => const TradeScreen(),
      ),
      GoRoute(
        path: '/verify-handshake/:tradeId',
        builder: (context, state) {
          final trade = state.extra as DisplayTrade;
          return VerifyHandshakeScreen(trade: trade);
        },
      ),
      GoRoute(
        path: '/command/:tradeId',
        builder: (context, state) => CommandCenterPage(
          tradeId: state.pathParameters['tradeId']!,
          workflowController: ref.read(workflowControllerProvider),
        ),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => ProfilePage(
          workflowController: ref.read(workflowControllerProvider),
        ),
      ),
    ],
  );
});

