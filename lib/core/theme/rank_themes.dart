/// Definição dos temas visuais por rank do sistema Dracoryx.
///
/// Cada rank (E → SSS) possui um [RankTheme] completo com cores,
/// gradientes e efeitos de glow neon. A classe [RankThemes] fornece
/// acesso estático a todos os temas e um método de lookup por nome.
library;

import 'package:flutter/material.dart';

/// Modelo de tema visual associado a um rank específico.
///
/// Contém todas as cores, gradientes e efeitos necessários para
/// estilizar a interface de acordo com o rank do usuário.
/// Cada rank possui uma paleta única que define a identidade visual.
class RankTheme {
  final String name;
  final Color primary;
  final Color accent;
  final Color background;
  final Color backgroundSecondary;
  final Color surface;
  final Color surfaceLight;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color success;
  final Color warning;
  final Color error;
  
  final LinearGradient primaryGradient;
  final LinearGradient backgroundGradient;
  final List<BoxShadow> neonGlowEffect;
  
  RankTheme({
    required this.name,
    required this.primary,
    required this.accent,
    required this.background,
    required this.backgroundSecondary,
    required this.surface,
    required this.surfaceLight,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.success,
    required this.warning,
    required this.error,
    required this.primaryGradient,
    required this.backgroundGradient,
    required this.neonGlowEffect,
  });
}

/// Repositório estático de temas para todos os ranks do sistema.
///
/// Fornece acesso aos 8 temas predefinidos (E, D, C, B, A, S, SS, SSS)
/// e um método [getTheme] para lookup dinâmico por nome de rank.
class RankThemes {
  /// Retorna o [RankTheme] correspondente ao [rank] informado.
  ///
  /// O [rank] é case-insensitive. Retorna o tema E como fallback
  /// para ranks desconhecidos.
  static RankTheme getTheme(String rank) {
    switch (rank.toUpperCase()) {
      case 'E':
        return RankThemes.e;
      case 'D':
        return RankThemes.d;
      case 'C':
        return RankThemes.c;
      case 'B':
        return RankThemes.b;
      case 'A':
        return RankThemes.a;
      case 'S':
        return RankThemes.s;
      case 'SS':
        return RankThemes.ss;
      case 'SSS':
        return RankThemes.sss;
      default:
        return RankThemes.e;
    }
  }
  
  // RANK E - Cinza/Prata (Iniciante)
  static final RankTheme e = RankTheme(
    name: 'E',
    primary: const Color(0xFF9E9E9E),
    accent: const Color(0xFFBDBDBD),
    background: const Color(0xFF1A1A1A),
    backgroundSecondary: const Color(0xFF2A2A2A),
    surface: const Color(0xFF242424),
    surfaceLight: const Color(0xFF3A3A3A),
    textPrimary: const Color(0xFFE0E0E0),
    textSecondary: const Color(0xFFB0B0B0),
    textTertiary: const Color(0xFF808080),
    success: const Color(0xFF4CAF50),
    warning: const Color(0xFFFFA726),
    error: const Color(0xFFEF5350),
    primaryGradient: const LinearGradient(
      colors: [Color(0xFF9E9E9E), Color(0xFFBDBDBD)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    backgroundGradient: const LinearGradient(
      colors: [Color(0xFF1A1A1A), Color(0xFF2A2A2A)],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ),
    neonGlowEffect: [
      BoxShadow(
        color: const Color(0xFF9E9E9E).withOpacity(0.5),
        blurRadius: 20,
        spreadRadius: 2,
      ),
    ],
  );
  
  // RANK D - Verde (Progredindo)
  static final RankTheme d = RankTheme(
    name: 'D',
    primary: const Color(0xFF66BB6A),
    accent: const Color(0xFF81C784),
    background: const Color(0xFF1A1F1A),
    backgroundSecondary: const Color(0xFF2A332A),
    surface: const Color(0xFF242924),
    surfaceLight: const Color(0xFF3A443A),
    textPrimary: const Color(0xFFE8F5E9),
    textSecondary: const Color(0xFFC8E6C9),
    textTertiary: const Color(0xFFA5D6A7),
    success: const Color(0xFF4CAF50),
    warning: const Color(0xFFFFA726),
    error: const Color(0xFFEF5350),
    primaryGradient: const LinearGradient(
      colors: [Color(0xFF66BB6A), Color(0xFF81C784)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    backgroundGradient: const LinearGradient(
      colors: [Color(0xFF1A1F1A), Color(0xFF2A332A)],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ),
    neonGlowEffect: [
      BoxShadow(
        color: const Color(0xFF66BB6A).withOpacity(0.5),
        blurRadius: 20,
        spreadRadius: 2,
      ),
    ],
  );
  
  // RANK C - Azul (Competente)
  static final RankTheme c = RankTheme(
    name: 'C',
    primary: const Color(0xFF42A5F5),
    accent: const Color(0xFF64B5F6),
    background: const Color(0xFF1A1D24),
    backgroundSecondary: const Color(0xFF2A2F3A),
    surface: const Color(0xFF242833),
    surfaceLight: const Color(0xFF3A4050),
    textPrimary: const Color(0xFFE3F2FD),
    textSecondary: const Color(0xFFBBDEFB),
    textTertiary: const Color(0xFF90CAF9),
    success: const Color(0xFF4CAF50),
    warning: const Color(0xFFFFA726),
    error: const Color(0xFFEF5350),
    primaryGradient: const LinearGradient(
      colors: [Color(0xFF42A5F5), Color(0xFF64B5F6)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    backgroundGradient: const LinearGradient(
      colors: [Color(0xFF1A1D24), Color(0xFF2A2F3A)],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ),
    neonGlowEffect: [
      BoxShadow(
        color: const Color(0xFF42A5F5).withOpacity(0.5),
        blurRadius: 20,
        spreadRadius: 2,
      ),
    ],
  );
  
  // RANK B - Roxo (Forte)
  static final RankTheme b = RankTheme(
    name: 'B',
    primary: const Color(0xFF7E57C2),
    accent: const Color(0xFF9575CD),
    background: const Color(0xFF1D1A24),
    backgroundSecondary: const Color(0xFF2F2A3A),
    surface: const Color(0xFF282433),
    surfaceLight: const Color(0xFF403A50),
    textPrimary: const Color(0xFFEDE7F6),
    textSecondary: const Color(0xFFD1C4E9),
    textTertiary: const Color(0xFFB39DDB),
    success: const Color(0xFF4CAF50),
    warning: const Color(0xFFFFA726),
    error: const Color(0xFFEF5350),
    primaryGradient: const LinearGradient(
      colors: [Color(0xFF7E57C2), Color(0xFF9575CD)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    backgroundGradient: const LinearGradient(
      colors: [Color(0xFF1D1A24), Color(0xFF2F2A3A)],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ),
    neonGlowEffect: [
      BoxShadow(
        color: const Color(0xFF7E57C2).withOpacity(0.5),
        blurRadius: 20,
        spreadRadius: 2,
      ),
    ],
  );
  
  // RANK A - Laranja (Poderoso)
  static final RankTheme a = RankTheme(
    name: 'A',
    primary: const Color(0xFFFF7043),
    accent: const Color(0xFFFF8A65),
    background: const Color(0xFF241A1A),
    backgroundSecondary: const Color(0xFF3A2A2A),
    surface: const Color(0xFF332424),
    surfaceLight: const Color(0xFF503A3A),
    textPrimary: const Color(0xFFFBE9E7),
    textSecondary: const Color(0xFFFFCCBC),
    textTertiary: const Color(0xFFFFAB91),
    success: const Color(0xFF4CAF50),
    warning: const Color(0xFFFFA726),
    error: const Color(0xFFEF5350),
    primaryGradient: const LinearGradient(
      colors: [Color(0xFFFF7043), Color(0xFFFF8A65)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    backgroundGradient: const LinearGradient(
      colors: [Color(0xFF241A1A), Color(0xFF3A2A2A)],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ),
    neonGlowEffect: [
      BoxShadow(
        color: const Color(0xFFFF7043).withOpacity(0.5),
        blurRadius: 20,
        spreadRadius: 2,
      ),
    ],
  );
  
  // RANK S - Dourado (Elite)
  static final RankTheme s = RankTheme(
    name: 'S',
    primary: const Color(0xFFFFD700),
    accent: const Color(0xFFFFC107),
    background: const Color(0xFF1F1A10),
    backgroundSecondary: const Color(0xFF332A1A),
    surface: const Color(0xFF2B2418),
    surfaceLight: const Color(0xFF443A28),
    textPrimary: const Color(0xFFFFF8E1),
    textSecondary: const Color(0xFFFFECB3),
    textTertiary: const Color(0xFFFFE082),
    success: const Color(0xFF4CAF50),
    warning: const Color(0xFFFFA726),
    error: const Color(0xFFEF5350),
    primaryGradient: const LinearGradient(
      colors: [Color(0xFFFFD700), Color(0xFFFFC107)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    backgroundGradient: const LinearGradient(
      colors: [Color(0xFF1F1A10), Color(0xFF332A1A)],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ),
    neonGlowEffect: [
      BoxShadow(
        color: const Color(0xFFFFD700).withOpacity(0.6),
        blurRadius: 30,
        spreadRadius: 5,
      ),
    ],
  );
  
  // RANK SS - Platina/Diamante (Lendário)
  static final RankTheme ss = RankTheme(
    name: 'SS',
    primary: const Color(0xFF00E5FF),
    accent: const Color(0xFF18FFFF),
    background: const Color(0xFF0A1418),
    backgroundSecondary: const Color(0xFF152428),
    surface: const Color(0xFF0F1C20),
    surfaceLight: const Color(0xFF1F3238),
    textPrimary: const Color(0xFFE0F7FA),
    textSecondary: const Color(0xFFB2EBF2),
    textTertiary: const Color(0xFF80DEEA),
    success: const Color(0xFF4CAF50),
    warning: const Color(0xFFFFA726),
    error: const Color(0xFFEF5350),
    primaryGradient: const LinearGradient(
      colors: [Color(0xFF00E5FF), Color(0xFF18FFFF), Color(0xFF00BCD4)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    backgroundGradient: const LinearGradient(
      colors: [Color(0xFF0A1418), Color(0xFF152428)],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ),
    neonGlowEffect: [
      BoxShadow(
        color: const Color(0xFF00E5FF).withOpacity(0.7),
        blurRadius: 40,
        spreadRadius: 8,
      ),
      BoxShadow(
        color: const Color(0xFF18FFFF).withOpacity(0.5),
        blurRadius: 60,
        spreadRadius: 10,
      ),
    ],
  );
  
  // RANK SSS - Roxo Místico (Monarca)
  static final RankTheme sss = RankTheme(
    name: 'SSS',
    primary: const Color(0xFFAB47BC),
    accent: const Color(0xFFCE93D8),
    background: const Color(0xFF120A1C),
    backgroundSecondary: const Color(0xFF1E1528),
    surface: const Color(0xFF18101F),
    surfaceLight: const Color(0xFF2A1F35),
    textPrimary: const Color(0xFFF3E5F5),
    textSecondary: const Color(0xFFE1BEE7),
    textTertiary: const Color(0xFFCE93D8),
    success: const Color(0xFF4CAF50),
    warning: const Color(0xFFFFA726),
    error: const Color(0xFFEF5350),
    primaryGradient: const LinearGradient(
      colors: [Color(0xFFAB47BC), Color.fromARGB(255, 183, 75, 202), Color(0xFF9C27B0)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    backgroundGradient: const LinearGradient(
      colors: [Color(0xFF120A1C), Color(0xFF1E1528), Color(0xFF0D0616)],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ),
    neonGlowEffect: [
      BoxShadow(
        color: const Color(0xFFAB47BC).withOpacity(0.8),
        blurRadius: 50,
        spreadRadius: 10,
      ),
      BoxShadow(
        color: const Color(0xFFCE93D8).withOpacity(0.6),
        blurRadius: 80,
        spreadRadius: 15,
      ),
    ],
  );
}
