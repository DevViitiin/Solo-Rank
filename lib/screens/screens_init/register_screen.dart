import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:monarch/core/theme/rank_themes.dart';
import 'package:monarch/screens/screens_init/server_select.dart';
import 'package:monarch/services/auth_service.dart';


class RegisterScreen extends StatefulWidget {
  const RegisterScreen({Key? key}) : super(key: key);
  
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> with SingleTickerProviderStateMixin {
  // Controllers
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  // Serviço
  final _authService = AuthService();
  
  // Estados
  bool _loading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _agreedToTerms = false;
  
  // Tema
  final RankTheme _theme = RankThemes.c;
  
  // Animações
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  
  @override
  void initState() {
    super.initState();
    _setupAnimations();
  }
  
  void _setupAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.2, 0.8, curve: Curves.easeOutCubic),
      ),
    );
    
    _animationController.forward();
  }
  
  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _animationController.dispose();
    super.dispose();
  }
  
  /// Realiza o cadastro
  /// 
  /// Etapas:
  /// 1. Valida todos os campos
  /// 2. Cria o usuário no Firebase Authentication
  /// 3. Redireciona para a tela de seleção de servidor
  /// 
  /// O usuário só será criado no banco de dados após escolher um servidor
  Future<void> _register() async {
    // Validações
    if (_nameController.text.isEmpty ||
        _emailController.text.isEmpty ||
        _passwordController.text.isEmpty ||
        _confirmPasswordController.text.isEmpty) {
      _showError('Preencha todos os campos');
      return;
    }
    
    if (_nameController.text.length < 3) {
      _showError('Nome deve ter pelo menos 3 caracteres');
      return;
    }
    
    if (!_emailController.text.contains('@')) {
      _showError('E-mail inválido');
      return;
    }
    
    if (_passwordController.text.length < 6) {
      _showError('Senha deve ter pelo menos 6 caracteres');
      return;
    }
    
    if (_passwordController.text != _confirmPasswordController.text) {
      _showError('As senhas não coincidem');
      return;
    }
    
    if (!_agreedToTerms) {
      _showError('Você precisa aceitar os termos de uso e política de privacidade');
      return;
    }
    
    setState(() => _loading = true);
    
    try {
      print('Iniciando criação de usuário...');
      
      // Cria conta no Firebase Auth
      final userId = await _authService.createUser(
        _emailController.text.trim(),
        _passwordController.text,
      );
      
      print('Usuário criado com sucesso. UID: $userId');
      
      if (!mounted) {
        print('Widget foi desmontado, cancelando navegação');
        return;
      }
      
      // Salva os dados para passar para a próxima tela
      final userName = _nameController.text.trim();
      final userEmail = _emailController.text.trim();
      
      print('Navegando para seleção de servidor...');
      
      // Navega para seleção de servidor
      // terms = true será salvo quando o usuário for criado no database
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ServerSelectionScreen(
            userId: userId,
            userName: userName,
            userEmail: userEmail,
            terms: true, // Usuário aceitou os termos
          ),
        ),
      );
    } catch (e, stackTrace) {
      print('Erro durante cadastro: $e');
      print('Stack trace: $stackTrace');
      
      if (mounted) {
        // Extrai a mensagem de erro mais amigável
        String errorMessage = e.toString();
        
        // Remove "Exception: " se presente
        if (errorMessage.startsWith('Exception: ')) {
          errorMessage = errorMessage.substring(11);
        }
        
        _showError(errorMessage);
        setState(() => _loading = false);
      }
    }
  }
  
  /// Abre URL em navegador externo
  ///  MELHORADO: Tenta diferentes modos de abertura e mostra erro detalhado
  Future<void> _launchURL(String url) async {
    try {
      final uri = Uri.parse(url);
      
      print('🔗 Tentando abrir URL: $url');
      
      // Tenta abrir em navegador externo primeiro
      bool launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      
      if (!launched) {
        print('❌ Falha ao abrir em navegador externo, tentando modo padrão...');
        
        // Tenta modo padrão
        launched = await launchUrl(uri);
        
        if (!launched) {
          print('❌ Falha ao abrir URL');
          if (mounted) {
            _showError('Não foi possível abrir o link. Copie e cole no navegador: $url');
          }
        } else {
          print('✅ URL aberta em modo padrão');
        }
      } else {
        print('✅ URL aberta em navegador externo');
      }
    } catch (e) {
      print('❌ Erro ao abrir URL: $e');
      if (mounted) {
        _showError('Erro ao abrir link: $e');
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
        duration: const Duration(seconds: 4),
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
              // Header com botão voltar
              _buildHeader(),
              
              // Conteúdo rolável
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 30),
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: Column(
                        children: [
                          const SizedBox(height: 20),
                          
                          // Título
                          _buildTitle(),
                          
                          const SizedBox(height: 40),
                          
                          // Campo Nome
                          _buildTextField(
                            controller: _nameController,
                            label: 'NOME DO CAÇADOR',
                            hint: 'Digite seu nome',
                            icon: Icons.badge_outlined,
                          ),
                          
                          const SizedBox(height: 20),
                          
                          // Campo Email
                          _buildTextField(
                            controller: _emailController,
                            label: 'E-MAIL',
                            hint: 'Digite seu e-mail',
                            icon: Icons.email_outlined,
                            keyboardType: TextInputType.emailAddress,
                          ),
                          
                          const SizedBox(height: 20),
                          
                          // Campo Senha
                          _buildTextField(
                            controller: _passwordController,
                            label: 'SENHA',
                            hint: 'Mínimo 6 caracteres',
                            icon: Icons.lock_outline,
                            obscureText: _obscurePassword,
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword ? Icons.visibility_off : Icons.visibility,
                                color: _theme.textSecondary,
                                size: 20,
                              ),
                              onPressed: () {
                                setState(() => _obscurePassword = !_obscurePassword);
                              },
                            ),
                          ),
                          
                          const SizedBox(height: 20),
                          
                          // Campo Confirmar Senha
                          _buildTextField(
                            controller: _confirmPasswordController,
                            label: 'CONFIRMAR SENHA',
                            hint: 'Digite a senha novamente',
                            icon: Icons.lock_outline,
                            obscureText: _obscureConfirmPassword,
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
                                color: _theme.textSecondary,
                                size: 20,
                              ),
                              onPressed: () {
                                setState(() => _obscureConfirmPassword = !_obscureConfirmPassword);
                              },
                            ),
                          ),
                          
                          const SizedBox(height: 24),
                          
                          // Checkbox termos
                          _buildTermsCheckbox(),
                          
                          const SizedBox(height: 32),
                          
                          // Botão Cadastrar
                          _buildRegisterButton(),
                          
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              color: _theme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _theme.surfaceLight,
                width: 1,
              ),
            ),
            child: IconButton(
              icon: Icon(
                Icons.arrow_back,
                color: _theme.primary,
              ),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildTitle() {
    return Column(
      children: [
        // Ícone
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: _theme.primaryGradient,
            boxShadow: _theme.neonGlowEffect,
          ),
          child: Icon(
            Icons.person_add,
            size: 40,
            color: _theme.textPrimary,
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Título
        ShaderMask(
          shaderCallback: (bounds) => _theme.primaryGradient.createShader(bounds),
          child: const Text(
            'CRIAR CONTA',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
              color: Colors.white,
            ),
          ),
        ),
        
        const SizedBox(height: 8),
        
        // Subtítulo
        Text(
          'Junte-se aos caçadores',
          style: TextStyle(
            fontSize: 14,
            color: _theme.textSecondary,
          ),
        ),
      ],
    );
  }
  
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool obscureText = false,
    Widget? suffixIcon,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
            color: _theme.primary,
          ),
        ),
        
        const SizedBox(height: 8),
        
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: TextField(
            controller: controller,
            obscureText: obscureText,
            keyboardType: keyboardType,
            style: TextStyle(
              color: _theme.textPrimary,
              fontSize: 16,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                color: _theme.textTertiary.withOpacity(0.5),
                fontSize: 14,
              ),
              prefixIcon: Icon(
                icon,
                color: _theme.primary,
                size: 22,
              ),
              suffixIcon: suffixIcon,
              filled: true,
              fillColor: _theme.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: _theme.surfaceLight,
                  width: 1,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: _theme.primary,
                  width: 2,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildTermsCheckbox() {
    return InkWell(
      onTap: () {
        setState(() => _agreedToTerms = !_agreedToTerms);
      },
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            margin: const EdgeInsets.only(top: 2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: _agreedToTerms ? _theme.primary : _theme.surfaceLight,
                width: 2,
              ),
              color: _agreedToTerms ? _theme.primary : Colors.transparent,
            ),
            child: _agreedToTerms
                ? const Icon(
                    Icons.check,
                    size: 16,
                    color: Colors.white,
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(
                  fontSize: 13,
                  color: _theme.textSecondary,
                  height: 1.4,
                ),
                children: [
                  const TextSpan(text: 'Eu aceito os '),
                  TextSpan(
                    text: 'termos de uso',
                    style: TextStyle(
                      color: _theme.primary,
                      fontWeight: FontWeight.bold,
                      decoration: TextDecoration.underline,
                    ),
                    recognizer: TapGestureRecognizer()
                      ..onTap = () {
                        _launchURL('https://spikeapp-asvnylwm.manus.space/terms');
                      },
                  ),
                  const TextSpan(text: ' e '),
                  TextSpan(
                    text: 'política de privacidade',
                    style: TextStyle(
                      color: _theme.primary,
                      fontWeight: FontWeight.bold,
                      decoration: TextDecoration.underline,
                    ),
                    recognizer: TapGestureRecognizer()
                      ..onTap = () {
                        _launchURL('https://spikeapp-asvnylwm.manus.space/privacy');
                      },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildRegisterButton() {
    return Container(
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
          onTap: _loading ? null : _register,
          borderRadius: BorderRadius.circular(12),
          child: Center(
            child: _loading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  )
                : const Text(
                    'CRIAR CONTA',
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
    );
  }
}
