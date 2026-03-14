import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// Reusable header widget for the app, displaying a title and optional actions.
class AppHeader extends StatelessWidget {
  /// Creates an [AppHeader].
  ///
  /// [title] is required and displayed as the header text.
  /// [actions] is an optional list of widgets (e.g., IconButtons) shown on the right.
  const AppHeader({super.key, required this.title, this.actions});

  final String title;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF8B0000),
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: <Widget>[
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            // If actions are provided, spread them into the row.
            if (actions != null) ...actions!,
          ],
        ),
      ),
    );
  }
}