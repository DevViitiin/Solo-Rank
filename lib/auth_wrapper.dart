import 'package:flutter/material.dart';
import 'package:monarch/core/theme/rank_themes.dart';
import 'package:monarch/screens/screens_init/login_screen.dart';
import 'package:monarch/screens/screens_init/server_select.dart';
import 'package:monarch/screens/screens_app/welcome_screen.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../providers/user_provider.dart';


class AuthWrapper extends StatefulWidget {
  const AuthWrapper({Key? key}) : super(key: key);

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  final _authService = AuthService();
  bool _isInitialized = false;
  bool _isAuthenticated = false;
  bool _hasUserData = false;
  final RankTheme _theme = RankThemes.c;
  
  @override
  void initState() {
    super.initState();
    _initializeAuth();
  }

  Future<void> _initializeAuth() async {
    final user = _authService.currentUser;
    
    if (user == null) {
      if (mounted) {
        setState(() {
          _isAuthenticated = false;
          _isInitialized = true;
        });
      }
      return;
    }

    try {
      await context.read<UserProvider>().loadUser();
      
      if (mounted) {
        final userProvider = context.read<UserProvider>();
        
        final hasCompleteUserData = userProvider.currentUser != null && 
                                      userProvider.currentServerId != null;
        setState(() {
          _isAuthenticated = true;
          _hasUserData = hasCompleteUserData;
          _isInitialized = true;
        });
      }
    } catch (e) {
      print('❌ Erro ao carregar usuário: $e');
      if (mounted) {
        setState(() {
          _isAuthenticated = true;
          _hasUserData = false;
          _isInitialized = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return _buildLoadingScreen();
    }

    if (!_isAuthenticated) {
      print('📍 AuthWrapper: Redirecionando para LOGIN (não autenticado)');
      return const LoginScreen();
    }

    if (!_hasUserData) {
      final user = _authService.currentUser!;
      print('📍 AuthWrapper: Redirecionando para SERVER SELECT (sem dados completos)');
      print('   User: ${user.email}');
      
      return ServerSelectionScreen(
        userId: user.uid,
        userName: user.displayName ?? 'Jogador',
        userEmail: user.email ?? '',
        terms: true, 
      );
    }

    return const WelcomeScreen(showAnimation: false);
  }

  Widget _buildLoadingScreen() {
    return Scaffold(
      backgroundColor: _theme.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: _theme.primaryGradient,
                boxShadow: _theme.neonGlowEffect,
              ),
              child: Icon(
                Icons.bolt,
                size: 80,
                color: _theme.textPrimary,
              ),
            ),
            const SizedBox(height: 40),

            Text(
              'Nivex',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w900,
                letterSpacing: 3,
                color: _theme.textPrimary,
              ),
            ),
            const SizedBox(height: 12),

            Text(
              'SISTEMA DE EVOLUÇÃO',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 4,
                color: _theme.textSecondary,
              ),
            ),
            const SizedBox(height: 40),

            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation(_theme.primary),
              strokeWidth: 3,
            ),
            const SizedBox(height: 24),

            Text(
              'Carregando...',
              style: TextStyle(
                color: _theme.textSecondary,
                fontSize: 14,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}