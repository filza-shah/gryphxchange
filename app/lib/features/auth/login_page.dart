import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers/auth_provider.dart';

/// Login screen for students
/// This screen does 3 main things:
/// 1) validates email/password input
/// 2) sets auth state to logged in
/// 3) sends the user to /home through go_router
class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  /// Reads text from the email input
  final TextEditingController _emailController = TextEditingController();

  /// Reads text from the password input
  final TextEditingController _passwordController = TextEditingController();

  /// Toggles password visibility on/off
  bool _showPassword = false;

  /// Current error message shown under the app title
  String _error = '';

  /// Handles the Login button tap
  /// Note! This is client-side validation only for now
  /// Real backend authentication can be implemented later (when we figure it out)
  void _handleLogin() {
    final String email = _emailController.text.trim();
    final String password = _passwordController.text;

    setState(() {
      _error = '';
    });

    if (!email.endsWith('@uoguelph.ca')) {
      setState(() {
        _error = 'Please use a valid @uoguelph.ca email address';
      });
      return;
    }

    if (password.isEmpty) {
      setState(() {
        _error = 'Please enter your password';
      });
      return;
    }

    ref.read(authServiceProvider).signIn(email: email, password: password).then((_) {
      // Authentication successful, auth state will update and trigger router redirect
    }).catchError((error) {
      setState(() {
        _error = 'Login failed. Please check your credentials and try again.';
      });
    });

    // Move to home. Router redirect rules also use authProvider so app-level guards stay consistent
    if (mounted) {
      context.go('/home');
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        // Background styling for the login screen
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(-0.75, -0.9),
            radius: 1.35,
            colors: <Color>[
              Color(0xFF3A0A0A), // deep red highlight center
              Color(0xFF1C0505), // dark crimson mid
              Color(0xFF0D0202), // near-black edge
            ],
            stops: <double>[0.0, 0.58, 1.0],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 22),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: const Border(
                    top: BorderSide(
                      color: Color(0xFFFFD700),
                      width: 3,
                    ), // gold accent stripe
                  ),
                  boxShadow: const <BoxShadow>[
                    BoxShadow(
                      blurRadius: 22,
                      offset: Offset(0, 10),
                      color: Color(0x40000000),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Image.asset(
                      'assets/images/gryphxchange_logo.png',
                      width: 120,
                      height: 120,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'GryphXChange',
                      style: TextStyle(
                        color: Color(0xFF8B0000), // Guelph maroon
                        fontSize: 36,
                        fontWeight: FontWeight.w700,
                        height: 1.08,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'University of Guelph Student Marketplace',
                      style: TextStyle(color: Colors.grey.shade700),
                      textAlign: TextAlign.center,
                    ),
                    if (_error.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFEBEE),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFFFCDD2)),
                        ),
                        child: Text(
                          _error,
                          style: const TextStyle(color: Color(0xFFB71C1C)),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    // Email must be a valid UofG address for this prototype flow.
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      onChanged: (String value) {
                        setState(() {});
                        if (_error.isNotEmpty &&
                            value.endsWith('@uoguelph.ca')) {
                          _error = '';
                        }
                      },
                      decoration: InputDecoration(
                        labelText: 'University Email',
                        hintText: 'yourname@uoguelph.ca',
                        helperText:
                            _emailController.text.isNotEmpty &&
                                !_emailController.text.endsWith('@uoguelph.ca')
                            ? 'Must be a @uoguelph.ca email address'
                            : ' ',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Password field (only checks non-empty for now).
                    TextField(
                      controller: _passwordController,
                      obscureText: !_showPassword,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _showPassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
                          onPressed: () {
                            setState(() {
                              _showPassword = !_showPassword;
                            });
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        // Triggers validation + auth state update + navigation.
                        onPressed: _handleLogin,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF8B0000),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('Login'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "Don't have an account yet? Sign up",
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
