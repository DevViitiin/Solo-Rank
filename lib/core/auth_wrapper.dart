/// Widget de decisão de rota baseado no estado de autenticação.
///
/// Responsável por direcionar o usuário para a tela correta ao abrir o app:
/// - [LoginScreen] se não autenticado
/// - [ServerSelectionScreen] se autenticado mas sem servidor/dados
/// - [WelcomeScreen] se autenticado e com dados completos
///
/// Exibe uma splash screen animada enquanto verifica o estado.
library;

import 'package:flutter/material.dart';
import 'package:monarch/core/theme/rank_themes.dart';
import 'package:monarch/screens/auth/login_screen.dart';
import 'package:monarch/screens/auth/server_select.dart';
import 'package:monarch/screens/app/welcome_screen.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../providers/user_provider.dart';

/// Wrapper de autenticação que decide qual tela exibir.
///
/// Fluxo de decisão:
/// 1. Verifica se há usuário Firebase autenticado
/// 2. Tenta carregar dados do usuário via [UserProvider]
/// 3. Redireciona conforme o estado encontrado
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({Key? key}) : super(key: key);

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  final _authService = AuthService();

  /// Indica se a verificação inicial de autenticação foi concluída.
  bool _isInitialized = false;

  /// Indica se existe um usuário Firebase autenticado.
  bool _isAuthenticated = false;

  /// Indica se o usuário possui dados completos (perfil + servidor).
  bool _hasUserData = false;

  /// Controla exibição do onboarding para novos usuários.
  bool _showOnboarding = false;

  /// Tema visual usado na splash screen de carregamento.
  final RankTheme _theme = RankThemes.c;

  @override
  void initState() {
    super.initState();
    _initializeAuth();
  }

  /// Verifica o estado de autenticação e carrega dados do usuário.
  ///
  /// Se houver usuário Firebase autenticado, tenta carregar seus dados
  /// via [UserProvider]. Em caso de erro, marca como autenticado
  /// mas sem dados (redirecionará para seleção de servidor).
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

        // ─────────────────────────────────────────────────────────────────

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
      return const LoginScreen();
    }

    if (!_hasUserData) {
      final user = _authService.currentUser!;
      return ServerSelectionScreen(
        userId: user.uid,
        userName: user.displayName ?? 'Jogador',
        userEmail: user.email ?? '',
        terms: true,
      );
    }
    // ─────────────────────────────────────────────────────────────────────

    return const WelcomeScreen(showAnimation: false);
  }

  /// Constrói a splash screen exibida durante a inicialização.
  ///
  /// Mostra o logo do Dracoryx com animação de carregamento
  /// usando o tema visual do rank C como padrão.
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
              child: Icon(Icons.bolt, size: 80, color: _theme.textPrimary),
            ),
            const SizedBox(height: 40),
            Text(
              'Dracoryx',
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
