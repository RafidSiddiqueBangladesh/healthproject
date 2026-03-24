import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'home_screen.dart';
import '../services/auth_service.dart';
import '../widgets/liquid_glass.dart';

class AuthScreen extends StatefulWidget {
  @override
  _AuthScreenState createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final AuthService _authService = AuthService();
  late final StreamSubscription<AuthState> _authSubscription;
  bool _awaitingOAuthResult = false;

  Future<void> _completeOAuthAndEnterApp() async {
    final hasSession = Supabase.instance.client.auth.currentSession != null;
    if (!hasSession) return;

    final result = await _authService.syncCurrentSessionWithBackend();
    if (!mounted) return;

    setState(() => _awaitingOAuthResult = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.message)));

    if (Supabase.instance.client.auth.currentSession != null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final hasSession = Supabase.instance.client.auth.currentSession != null;
      if (hasSession) {
        _completeOAuthAndEnterApp();
      }
    });

    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((state) async {
      if (state.event != AuthChangeEvent.signedIn) return;

      if (_awaitingOAuthResult || Supabase.instance.client.auth.currentSession != null) {
        await _completeOAuthAndEnterApp();
      }
    });
  }

  void _onOAuthStarted() {
    setState(() => _awaitingOAuthResult = true);
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('NutriCare'),
        bottom: TabBar(
          indicatorColor: const Color(0xFFD2FFFA),
          labelColor: const Color(0xFFE9FFFB),
          unselectedLabelColor: const Color(0xB7D7E4E2),
          controller: _tabController,
          tabs: const [
            Tab(text: 'Sign In'),
            Tab(text: 'Sign Up'),
          ],
        ),
      ),
      body: LiquidGlassBackground(
        child: TabBarView(
          controller: _tabController,
          children: [
            SignInTab(authService: _authService, onOAuthStarted: _onOAuthStarted),
            SignUpTab(authService: _authService, onOAuthStarted: _onOAuthStarted),
          ],
        ),
      ),
    );
  }
}

class SignInTab extends StatefulWidget {
  const SignInTab({super.key, required this.authService, required this.onOAuthStarted});

  final AuthService authService;
  final VoidCallback onOAuthStarted;

  @override
  State<SignInTab> createState() => _SignInTabState();
}

class _SignInTabState extends State<SignInTab> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isOAuthLoading = false;

  Future<void> _handleSignIn() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter email and password.')),
      );
      return;
    }

    setState(() => _isLoading = true);
    final result = await widget.authService.signInWithEmail(
      email: email,
      password: password,
    );
    if (!mounted) return;
    setState(() => _isLoading = false);

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.message)));

    if (result.success) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    }
  }

  Future<void> _handleOAuth(OAuthProvider provider) async {
    setState(() => _isOAuthLoading = true);
    final result = await widget.authService.signInWithOAuth(provider: provider);
    if (!mounted) return;
    setState(() => _isOAuthLoading = false);

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.message)));
    if (result.success) {
      widget.onOAuthStarted();
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
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          LiquidGlassCard(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            tint: const Color(0xFFAEEFFF),
            child: Column(
              children: [
                const Text(
                  'Welcome Back',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.alternate_email_rounded),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: Icon(Icons.lock_rounded),
                  ),
                  obscureText: true,
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleSignIn,
                    child: Text(_isLoading ? 'Signing In...' : 'Sign In'),
                  ),
                ),
                const SizedBox(height: 12),
                const Text('or continue with', style: TextStyle(color: Color(0xDCEFF8FF))),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _isOAuthLoading ? null : () => _handleOAuth(OAuthProvider.google),
                    icon: const Icon(Icons.g_mobiledata_rounded),
                    label: Text(_isOAuthLoading ? 'Opening...' : 'Continue with Google'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SignUpTab extends StatefulWidget {
  const SignUpTab({super.key, required this.authService, required this.onOAuthStarted});

  final AuthService authService;
  final VoidCallback onOAuthStarted;

  @override
  State<SignUpTab> createState() => _SignUpTabState();
}

class _SignUpTabState extends State<SignUpTab> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isOAuthLoading = false;

  Future<void> _handleSignUp() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill name, email, and password.')),
      );
      return;
    }

    setState(() => _isLoading = true);
    final result = await widget.authService.signUpWithEmail(
      name: name,
      email: email,
      password: password,
    );
    if (!mounted) return;
    setState(() => _isLoading = false);

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.message)));

    if (result.success && !result.message.toLowerCase().contains('check your email')) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    }
  }

  Future<void> _handleOAuth(OAuthProvider provider) async {
    setState(() => _isOAuthLoading = true);
    final result = await widget.authService.signInWithOAuth(provider: provider);
    if (!mounted) return;
    setState(() => _isOAuthLoading = false);

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.message)));
    if (result.success) {
      widget.onOAuthStarted();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          LiquidGlassCard(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            tint: const Color(0xFFC8FFD6),
            child: Column(
              children: [
                const Text(
                  'Create Your Account',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'Name',
                    prefixIcon: Icon(Icons.person_rounded),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.alternate_email_rounded),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: Icon(Icons.lock_rounded),
                  ),
                  obscureText: true,
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleSignUp,
                    child: Text(_isLoading ? 'Signing Up...' : 'Sign Up'),
                  ),
                ),
                const SizedBox(height: 12),
                const Text('or continue with', style: TextStyle(color: Color(0xDCEFF8FF))),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _isOAuthLoading ? null : () => _handleOAuth(OAuthProvider.google),
                    icon: const Icon(Icons.g_mobiledata_rounded),
                    label: Text(_isOAuthLoading ? 'Opening...' : 'Sign up with Google'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}