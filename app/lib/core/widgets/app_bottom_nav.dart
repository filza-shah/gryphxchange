import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AppBottomNav extends StatelessWidget {
  const AppBottomNav({super.key, required this.currentRoute});

  final String currentRoute;

  // quick heads-up: keep route order synced with nav item order.
  static const List<String> _routes = <String>[
    '/home',
    '/create',
    '/trades',
    '/wishlist',
    '/profile',
  ];

  int _activeIndex() {
    // tiny fallback so we always land somewhere sane.
    if (currentRoute == '/home' || currentRoute == '/') {
      return 0;
    }
    if (currentRoute == '/create') {
      return 1;
    }
    if (currentRoute == '/trades') {
      return 2;
    }
    if (currentRoute == '/wishlist') {
      return 3;
    }
    if (currentRoute == '/profile') {
      return 4;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: _activeIndex(),
      type: BottomNavigationBarType.fixed,
      selectedItemColor: const Color(0xFF8B0000),
      unselectedItemColor: Colors.grey.shade600,
      selectedLabelStyle: const TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 11,
      ),
      unselectedLabelStyle: const TextStyle(fontSize: 10),
      onTap: (int index) {
        final String targetRoute = _routes[index];
        // no need to re-push if user already on this tab.
        if (targetRoute == currentRoute) {
          return;
        }
        context.go(targetRoute);
      },
      items: const <BottomNavigationBarItem>[
        BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
        BottomNavigationBarItem(icon: Icon(Icons.add_circle), label: 'Post'),
        BottomNavigationBarItem(icon: Icon(Icons.swap_horiz), label: 'Trades'),
        BottomNavigationBarItem(
          icon: Icon(Icons.favorite_border),
          label: 'Wishlist',
        ),
        BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
      ],
    );
  }
}
