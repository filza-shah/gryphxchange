import 'package:flutter/material.dart';

import 'core/widgets/app_bottom_nav.dart';
import 'features/listing/listing_detail_page.dart';
import 'features/wishlist/wishlist_page.dart';
import 'services/workflow/workflow_controller.dart';

const Color _gryphRed = Color(0xFF8B0000);
const Color _gryphGold = Color(0xFFFFD700);
const Color _shellBackground = Color(0xFF101114);
const Color _pageBackground = Color(0xFFF5F5F5);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final WorkflowController workflowController = WorkflowController();
  await workflowController.init();
  runApp(GryphXChangeApp(workflowController: workflowController));
}

class GryphXChangeApp extends StatelessWidget {
  const GryphXChangeApp({super.key, required this.workflowController});

  final WorkflowController workflowController;

  Route<dynamic> _onGenerateRoute(RouteSettings settings) {
    final String name = settings.name ?? '/wishlist';
    final Uri uri = Uri.parse(name);

    if (uri.path == '/wishlist' || uri.path == '/') {
      return MaterialPageRoute<dynamic>(
        builder: (_) => WishlistPage(workflowController: workflowController),
        settings: settings,
      );
    }
    if (uri.pathSegments.length == 2 && uri.pathSegments.first == 'listing') {
      return MaterialPageRoute<dynamic>(
        builder: (_) => ListingDetailPage(listingId: uri.pathSegments[1]),
        settings: settings,
      );
    }
    if (uri.path == '/home' ||
        uri.path == '/create' ||
        uri.path == '/trades' ||
        uri.path == '/profile') {
      return MaterialPageRoute<dynamic>(
        builder: (_) => _PlaceholderPage(route: uri.path),
        settings: settings,
      );
    }

    return MaterialPageRoute<dynamic>(
      builder: (_) => WishlistPage(workflowController: workflowController),
      settings: settings,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: _pageBackground,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _gryphRed,
        primary: _gryphRed,
        secondary: _gryphGold,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: _gryphRed,
        foregroundColor: Colors.white,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: _gryphRed,
          foregroundColor: Colors.white,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(fontFamily: 'Inter'),
        bodyMedium: TextStyle(fontFamily: 'Inter'),
      ),
    );

    return MaterialApp(
      title: 'GryphXChange',
      debugShowCheckedModeBanner: false,
      theme: theme,
      initialRoute: '/wishlist',
      onGenerateRoute: _onGenerateRoute,
      builder: (BuildContext context, Widget? child) {
        return Container(
          color: _shellBackground,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Material(
                color: theme.scaffoldBackgroundColor,
                child: child ?? const SizedBox.shrink(),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PlaceholderPage extends StatelessWidget {
  const _PlaceholderPage({required this.route});

  final String route;

  String get _title {
    switch (route) {
      case '/home':
        return 'Home';
      case '/create':
        return 'Create Listing';
      case '/trades':
        return 'Trades';
      case '/profile':
        return 'Profile';
      default:
        return 'Page';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_title)),
      bottomNavigationBar: AppBottomNav(currentRoute: route),
      body: Center(
        child: Text(
          '$_title page is not ported yet.',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
