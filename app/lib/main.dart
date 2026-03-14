import 'package:flutter/material.dart';

// custom color constants for app theme
const Color _gryphRed = Color(0xFF8B0000);
const Color _gryphGold = Color(0xFFFFD700);
const Color _shellBackground = Color(0xFF101114);
const Color _pageBackground = Color(0xFFF5F5F5);

void main() {
  runApp(const GryphXChangeApp());
}

class GryphXChangeApp extends StatelessWidget {
  const GryphXChangeApp({super.key});

  @override
  Widget build(BuildContext context) {
    //overall app theme 
    final ThemeData theme = ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: _pageBackground,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _gryphRed,
        primary: _gryphRed, //main color for app elements
        secondary: _gryphGold, // accent color for highlights 
      ),

      appBarTheme: const AppBarTheme(
        backgroundColor: _gryphRed, // AppBar background color 
        foregroundColor: Colors.white, // AppBar text and icon color 
      ),

      // filled button style 
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: _gryphRed,
          foregroundColor: Colors.white,
          textStyle: const TextStyle(fontWeight: FontWeight.w600), // button text style
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10), // rounded corners for buttons
          ),
        ),
      ),

      // rounded card with with white background color and elevation 
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
      home: const ThemePreviewPage(),
    );
  }
}

//Page to preview the app's theme and widgtes 
class ThemePreviewPage extends StatelessWidget {
  const ThemePreviewPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('GryphXChange')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Theme Imported',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'test',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
          //filled button with icon example
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.swap_horiz),
            label: const Text('Create Trade'),
          ),
          //outlined box example
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () {},
            style: OutlinedButton.styleFrom(
              foregroundColor: _gryphRed,
              side: const BorderSide(color: _gryphRed),
            ),
            child: const Text('Secondary Action'),
          ),
          const SizedBox(height: 20),
          //chips to show color theme
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: const <Widget>[
              Chip(label: Text('Maroon Primary')),
              Chip(label: Text('Gold Accent')),
              Chip(label: Text('Mobile Frame')),
            ],
          ),
        ],
      ),
    );
  }
}
