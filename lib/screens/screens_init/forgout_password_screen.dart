import 'package:flutter/material.dart';
import 'package:monarch/core/theme/rank_themes.dart';
import 'package:monarch/services/auth_service.dart';

/// Tela de Recuperação de Senha — redesenhada
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({Key? key}) : super(key: key);

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen>
    with TickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _authService = AuthService();

  bool _loading = false;
  bool _emailSent = false;

  final RankTheme _theme = RankThemes.c;

  // Animações de entrada
  late AnimationController _entryController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  // Animação do ícone de sucesso
  late AnimationController _successController;
  late Animation<double> _successScale;
  late Animation<double> _successOpacity;

  // Animação do pulso no ícone principal
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();

    _entryController = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    );

    _fadeAnim = CurvedAnimation(
      parent: _entryController,
      curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
    );

    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.25),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entryController,
      curve: const Interval(0.1, 0.8, curve: Curves.easeOutCubic),
    ));

    _successController = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    );

    _successScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _successController, curve: Curves.elasticOut),
    );

    _successOpacity = CurvedAnimation(
      parent: _successController,
      curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
    );

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1800),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnim = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _entryController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _entryController.dispose();
    _successController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _enviarEmail() async {
    final email = _emailController.text.trim();

    if (email.isEmpty) {
      _mostrarErro('Digite seu e-mail para continuar');
      return;
    }
    if (!email.contains('@') || !email.contains('.')) {
      _mostrarErro('Digite um e-mail válido');
      return;
    }

    setState(() => _loading = true);

    try {
      await _authService.sendPasswordResetEmail(email);
      if (!mounted) return;

      setState(() {
        _loading = false;
        _emailSent = true;
      });
      _successController.forward(from: 0);
    } catch (e) {
      if (!mounted) return;
      String msg = e.toString();
      if (msg.startsWith('Exception: ')) msg = msg.substring(11);
      _mostrarErro(msg);
      setState(() => _loading = false);
    }
  }

  void _mostrarErro(String mensagem) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(mensagem,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w500)),
            ),
          ],
        ),
        backgroundColor: _theme.error,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'OK',
          textColor: Colors.white,
          onPressed: () =>
              ScaffoldMessenger.of(context).hideCurrentSnackBar(),
        ),
      ),
    );
  }

  void _reiniciar() {
    setState(() {
      _emailSent = false;
      _emailController.clear();
    });
    _entryController.forward(from: 0);
  }

  // ───────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: _theme.backgroundGradient),
        child: SafeArea(
          child: Column(
            children: [
              _buildBarra(),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 500),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeIn,
                  transitionBuilder: (child, anim) => FadeTransition(
                    opacity: anim,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.08),
                        end: Offset.zero,
                      ).animate(anim),
                      child: child,
                    ),
                  ),
                  child: _emailSent ? _buildSucesso() : _buildFormulario(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Barra superior ─────────────────────────────────────────────────────────

  Widget _buildBarra() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 16, 0),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_ios_new,
                color: _theme.textPrimary, size: 20),
            onPressed: () => Navigator.of(context).pop(),
          ),
          Text(
            'Recuperar senha',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: _theme.textSecondary,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  // ── Formulário ──────────────────────────────────────────────────────────────

  Widget _buildFormulario() {
    return FadeTransition(
      key: const ValueKey('form'),
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(28, 12, 28, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCabecalhoFormulario(),
              const SizedBox(height: 36),
              _buildDicasRapidas(),
              const SizedBox(height: 36),
              _buildCampoEmail(),
              const SizedBox(height: 32),
              _buildBotaoEnviar(),
              const SizedBox(height: 20),
              Center(
                child: GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Text(
                    'Voltar ao login',
                    style: TextStyle(
                      fontSize: 13,
                      color: _theme.textSecondary,
                      decoration: TextDecoration.underline,
                      decorationColor: _theme.textSecondary,
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

  Widget _buildCabecalhoFormulario() {
    return Row(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            ScaleTransition(
              scale: _pulseAnim,
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _theme.primary.withOpacity(0.25),
                    width: 2,
                  ),
                ),
              ),
            ),
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: _theme.primaryGradient,
                boxShadow: _theme.neonGlowEffect,
              ),
              child: Icon(Icons.lock_reset_rounded,
                  size: 28, color: _theme.textPrimary),
            ),
          ],
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ShaderMask(
                shaderCallback: (b) =>
                    _theme.primaryGradient.createShader(b),
                child: const Text(
                  'Esqueceu a senha?',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Enviaremos um link seguro para você criar uma nova senha.',
                style: TextStyle(
                  fontSize: 12,
                  color: _theme.textSecondary,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDicasRapidas() {
    final dicas = [
      (Icons.alternate_email_rounded, 'Use o e-mail cadastrado na sua conta'),
      (Icons.auto_delete_outlined, 'O link expira em 1 hora após o envio'),
      (
        Icons.folder_special_outlined,
        'Verifique spam, lixo eletrônico e promoções'
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: _theme.surface,
        border: Border.all(color: _theme.surfaceLight, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: dicas.asMap().entries.map((entry) {
          final i = entry.key;
          final dica = entry.value;
          final isLast = i == dicas.length - 1;
          return Column(
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _theme.primary.withOpacity(0.12),
                      ),
                      child:
                          Icon(dica.$1, color: _theme.primary, size: 17),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        dica.$2,
                        style: TextStyle(
                          fontSize: 13,
                          color: _theme.textSecondary,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (!isLast)
                Divider(
                  height: 1,
                  color: _theme.surfaceLight,
                  indent: 16,
                  endIndent: 16,
                ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCampoEmail() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'SEU E-MAIL',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 2.5,
            color: _theme.primary,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.35),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            style: TextStyle(color: _theme.textPrimary, fontSize: 15),
            decoration: InputDecoration(
              hintText: 'exemplo@email.com',
              hintStyle: TextStyle(
                color: _theme.textTertiary.withOpacity(0.45),
                fontSize: 14,
              ),
              prefixIcon: Icon(Icons.alternate_email_rounded,
                  color: _theme.primary, size: 20),
              filled: true,
              fillColor: _theme.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide:
                    BorderSide(color: _theme.surfaceLight, width: 1.5),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: _theme.primary, width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 17),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBotaoEnviar() {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: _theme.primaryGradient,
        boxShadow: _theme.neonGlowEffect,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _loading ? null : _enviarEmail,
          borderRadius: BorderRadius.circular(14),
          child: Center(
            child: _loading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2.5),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.send_rounded, color: Colors.white, size: 19),
                      SizedBox(width: 5),
                      Text(
                        'ENVIAR LINK DE RECUPERAÇÃO',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  // ── Tela de sucesso ─────────────────────────────────────────────────────────

  Widget _buildSucesso() {
    return FadeTransition(
      key: const ValueKey('sucesso'),
      opacity: _successOpacity,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(28, 16, 28, 32),
        child: Column(
          children: [
            const SizedBox(height: 16),
            _buildIconeSucesso(),
            const SizedBox(height: 28),
            _buildTituloSucesso(),
            const SizedBox(height: 36),
            _buildPassoAPasso(),
            const SizedBox(height: 36),
            _buildBotoesAcao(),
          ],
        ),
      ),
    );
  }

  Widget _buildIconeSucesso() {
    return ScaleTransition(
      scale: _successScale,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFF22C55E).withOpacity(0.2),
                width: 2,
              ),
            ),
          ),
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF16A34A).withOpacity(0.15),
              border: Border.all(
                color: const Color(0xFF22C55E).withOpacity(0.4),
                width: 1.5,
              ),
            ),
          ),
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF15803D).withOpacity(0.5),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF22C55E).withOpacity(0.35),
                  blurRadius: 24,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: const Icon(
              Icons.mark_email_read_rounded,
              size: 36,
              color: Color(0xFF4ADE80),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTituloSucesso() {
    return Column(
      children: [
        Text(
          'E-mail enviado!',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w900,
            color: _theme.textPrimary,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 10),
        RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: TextStyle(
                fontSize: 13, color: _theme.textSecondary, height: 1.6),
            children: [
              const TextSpan(text: 'Enviamos o link para\n'),
              TextSpan(
                text: _emailController.text.trim(),
                style: TextStyle(
                  color: _theme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPassoAPasso() {
    final passos = [
      _Passo(
        numero: '1',
        icone: Icons.inbox_rounded,
        titulo: 'Abra seu e-mail',
        descricao:
            'Acesse a caixa de entrada do e-mail cadastrado. O envio pode levar alguns minutos.',
      ),
      _Passo(
        numero: '2',
        icone: Icons.warning_amber_rounded,
        titulo: 'Não achou? Confira o spam',
        descricao:
            'Verifique spam, lixo eletrônico e promoções caso o e-mail não apareça na caixa de entrada.',
        destaque: true,
      ),
      _Passo(
        numero: '3',
        icone: Icons.touch_app_rounded,
        titulo: 'Clique em "Redefinir senha"',
        descricao:
            'Abra o e-mail da Dracoryx e toque no botão de redefinição. O link é válido por 1 hora.',
      ),
      _Passo(
        numero: '4',
        icone: Icons.lock_open_rounded,
        titulo: 'Crie sua nova senha',
        descricao:
            'Você será direcionado para uma página segura. Escolha uma senha forte e confirme.',
      ),
    ];

    return Column(
      children: passos
          .map((p) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _buildCardPasso(p),
              ))
          .toList(),
    );
  }

  Widget _buildCardPasso(_Passo passo) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: passo.destaque
            ? const Color(0xFFCA8A04).withOpacity(0.08)
            : _theme.surface,
        border: Border.all(
          color: passo.destaque
              ? const Color(0xFFCA8A04).withOpacity(0.4)
              : _theme.surfaceLight,
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: passo.destaque ? null : _theme.primaryGradient,
              color: passo.destaque
                  ? const Color(0xFFCA8A04).withOpacity(0.3)
                  : null,
            ),
            child: Center(
              child: Text(
                passo.numero,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: passo.destaque
                      ? const Color(0xFFFBBF24)
                      : _theme.textPrimary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      passo.icone,
                      size: 15,
                      color: passo.destaque
                          ? const Color(0xFFFBBF24)
                          : _theme.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      passo.titulo,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: passo.destaque
                            ? const Color(0xFFFBBF24)
                            : _theme.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  passo.descricao,
                  style: TextStyle(
                    fontSize: 12,
                    color: _theme.textSecondary,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBotoesAcao() {
    return Column(
      children: [
        Container(
          width: double.infinity,
          height: 56,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: _theme.primaryGradient,
            boxShadow: _theme.neonGlowEffect,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => Navigator.of(context).pop(),
              borderRadius: BorderRadius.circular(14),
              child: const Center(
                child: Text(
                  'VOLTAR AO LOGIN',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        GestureDetector(
          onTap: _reiniciar,
          child: Container(
            width: double.infinity,
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _theme.surfaceLight, width: 1.5),
            ),
            child: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.refresh_rounded,
                      color: _theme.textSecondary, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Usar outro e-mail',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _theme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Modelos ──────────────────────────────────────────────────────────────────

class _Passo {
  final String numero;
  final IconData icone;
  final String titulo;
  final String descricao;
  final bool destaque;

  const _Passo({
    required this.numero,
    required this.icone,
    required this.titulo,
    required this.descricao,
    this.destaque = false,
  });
}