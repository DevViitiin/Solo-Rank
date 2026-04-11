import 'package:flutter/material.dart';
import 'package:monarch/core/theme/rank_themes.dart';
import 'package:monarch/models/server_model.dart';
import 'package:monarch/providers/user_provider.dart';
import 'package:monarch/screens/app/welcome_screen.dart';
import 'package:monarch/services/database_service.dart';
import 'package:provider/provider.dart';

/// Tela de Seleção de Servidor após cadastro
class ServerSelectionScreen extends StatefulWidget {
  final String userId;
  final String userName;
  final String userEmail;
  final bool terms;

  const ServerSelectionScreen({
    Key? key,
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.terms,
  }) : super(key: key);

  @override
  State<ServerSelectionScreen> createState() => _ServerSelectionScreenState();
}

class _ServerSelectionScreenState extends State<ServerSelectionScreen>
    with SingleTickerProviderStateMixin {
  final _dbService = DatabaseService();

  List<ServerModel>? _servers;
  bool _isLoading = true;
  bool _isCreatingUser = false;
  String? _error;
  ServerModel? _selectedServer;

  final RankTheme _theme = RankThemes.c;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _loadServers();
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOut,
      ),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadServers() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await _dbService.ensureCurrentMonthServer();
      final servers = await _dbService.getActiveServers();

      setState(() {
        _servers = servers;
        _selectedServer = servers.isNotEmpty ? servers.first : null;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _confirmSelection() async {
    if (_selectedServer == null) {
      _showError('Selecione um servidor');
      return;
    }

    setState(() => _isCreatingUser = true);

    try {
      print('Criando usuário no servidor: ${_selectedServer!.id}');
      print('Terms accepted: ${widget.terms}');

      final userProvider = context.read<UserProvider>();

      // PASSANDO O PARÂMETRO TERMS
      await userProvider.createUserInServer(
        widget.userId,
        widget.userName,
        widget.userEmail,
        _selectedServer!.id,
        widget.terms, // ← ADICIONAR O PARÂMETRO TERMS AQUI
      );

      print('Usuário criado com sucesso!');

      if (mounted) {
        // Navega para WelcomeScreen COM animação (novo usuário)
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => const WelcomeScreen(showAnimation: true),
          ),
          (route) => false,
        );
      }
    } catch (e) {
      print('Erro ao criar usuário no servidor: $e');

      setState(() => _isCreatingUser = false);

      if (mounted) {
        _showError('Erro ao entrar no servidor: $e');
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: _theme.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: _theme.backgroundGradient,
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: _buildServerList(),
              ),
              _buildConfirmButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: _theme.primaryGradient,
                boxShadow: _theme.neonGlowEffect,
              ),
              child: Icon(
                Icons.dns,
                size: 40,
                color: _theme.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            ShaderMask(
              shaderCallback: (bounds) =>
                  _theme.primaryGradient.createShader(bounds),
              child: const Text(
                'SELECIONE UM SERVIDOR',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Escolha em qual servidor você deseja jogar',
              style: TextStyle(
                fontSize: 13,
                color: _theme.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServerList() {
    if (_isLoading && _servers == null) {
      return Center(
        child: CircularProgressIndicator(color: _theme.primary),
      );
    }

    if (_error != null) {
      return _buildErrorState();
    }

    if (_servers == null || _servers!.isEmpty) {
      return _buildEmptyState();
    }

    return FadeTransition(
      opacity: _fadeAnimation,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        itemCount: _servers!.length,
        itemBuilder: (context, index) {
          final server = _servers![index];
          final isSelected = _selectedServer?.id == server.id;
          final isRecommended = index == 0;

          return _ServerCard(
            server: server,
            isSelected: isSelected,
            isRecommended: isRecommended,
            theme: _theme,
            onTap: () {
              if (server.canJoin) {
                setState(() {
                  _selectedServer = server;
                  print('Servidor selecionado: ${server.displayName}');
                });
              }
            },
          );
        },
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 60, color: _theme.error),
          const SizedBox(height: 20),
          Text(
            'Erro ao carregar servidores',
            style: TextStyle(fontSize: 18, color: _theme.textSecondary),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _loadServers,
            style: ElevatedButton.styleFrom(
              backgroundColor: _theme.primary,
            ),
            child: const Text('Tentar Novamente'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.dns, size: 60, color: _theme.textTertiary),
          const SizedBox(height: 20),
          Text(
            'Nenhum servidor disponível',
            style: TextStyle(fontSize: 18, color: _theme.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmButton() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Container(
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: _theme.primaryGradient,
          boxShadow: _theme.neonGlowEffect,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: (_isCreatingUser || _selectedServer == null)
                ? null
                : _confirmSelection,
            borderRadius: BorderRadius.circular(12),
            child: Center(
              child: _isCreatingUser
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  : const Text(
                      'ENTRAR NO SERVIDOR',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ServerCard extends StatelessWidget {
  final ServerModel server;
  final bool isSelected;
  final bool isRecommended;
  final RankTheme theme;
  final VoidCallback onTap;

  const _ServerCard({
    required this.server,
    required this.isSelected,
    required this.isRecommended,
    required this.theme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final canJoin = server.canJoin;
    // CORREÇÃO: Cálculo correto da porcentagem
    final percentage = server.maxPlayers > 0 
        ? ((server.playerCount / server.maxPlayers) * 100).round() 
        : 0;

    Color statusColor;
    String statusText;

    if (!canJoin) {
      statusColor = theme.error;
      statusText = 'CHEIO';
    } else if (percentage > 75) {
      statusColor = theme.warning;
      statusText = 'QUASE CHEIO';
    } else {
      statusColor = theme.success;
      statusText = 'DISPONÍVEL';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: isSelected
            ? theme.primaryGradient
            : LinearGradient(
                colors: [theme.surface, theme.backgroundSecondary],
              ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? theme.primary : theme.surfaceLight,
          width: isSelected ? 2 : 1,
        ),
        boxShadow: isSelected ? theme.neonGlowEffect : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: canJoin ? onTap : null,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelected
                            ? Colors.white.withOpacity(0.2)
                            : theme.surfaceLight,
                      ),
                      child: Icon(
                        Icons.dns,
                        color: isSelected ? Colors.white : theme.primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        server.displayName,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? Colors.white : theme.textPrimary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      Icons.people,
                      size: 16,
                      color: isSelected ? Colors.white70 : theme.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${server.playerCount}/${server.maxPlayers} jogadores',
                      style: TextStyle(
                        fontSize: 13,
                        color:
                            isSelected ? Colors.white70 : theme.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Stack(
                  children: [
                    Container(
                      height: 6,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.white.withOpacity(0.2)
                            : theme.surfaceLight,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: percentage / 100,
                      child: Container(
                        height: 6,
                        decoration: BoxDecoration(
                          color: statusColor,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '$percentage% ocupado',
                  style: TextStyle(
                    fontSize: 11,
                    color: isSelected ? Colors.white60 : theme.textTertiary,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (isRecommended) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFFD700), Color(0xFFFFAF00)],
                          ),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'NOVO',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: statusColor, width: 1.5),
                      ),
                      child: Text(
                        statusText,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
