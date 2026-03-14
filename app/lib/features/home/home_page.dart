import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/widgets/app_bottom_nav.dart';
import '../../core/widgets/app_header.dart';
import '../../core/widgets/search_bar.dart';

// HomePage is a ConsumerWidget so it can access Riverpod providers
class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

    @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

    @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: const AppBottomNav(currentRoute: '/home'),
      body: Column(
        children: [
          const AppHeader(title: 'Listings'),
          ListingSearchBar(
            controller: _searchController,
            onChanged: (String value) => setState(() => _searchQuery = value),
          ),
          Expanded(
            child: Center(
              child: FilledButton(
                onPressed: () {
                  ref.read(authProvider.notifier).state = false;
                  context.go('/login');
                },
                child: const Text('Logout'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
 