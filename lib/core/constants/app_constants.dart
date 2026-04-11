/// Constantes do Aplicativo
/// 
/// Centraliza todas as constantes usadas no app para facilitar manutenção
library;

class AppConstants {
  // Previne instanciação
  AppConstants._();

  // ============================================================================
  // CONFIGURAÇÕES DO APP
  // ============================================================================
  
  static const String appName = 'Monarch - Sistema de Evolução';
  static const String appVersion = '1.0.0';
  
  // ============================================================================
  // RANKS DO SISTEMA
  // ============================================================================
  
  static const List<String> ranks = [
    'E',
    'D', 
    'C',
    'B',
    'A',
    'S',
    'SS',
    'SSS',
  ];
  
  // XP necessário para cada rank
  static const Map<String, int> rankXpRequirements = {
    'E': 0,
    'D': 1000,
    'C': 3000,
    'B': 6000,
    'A': 10000,
    'S': 15000,
    'SS': 25000,
    'SSS': 40000,
  };
  
  // ============================================================================
  // NÍVEIS E XP
  // ============================================================================
  
  static const int xpPerLevel = 100; // XP base por nível
  static const int maxLevel = 100;
  
  /// Calcula XP necessário para um nível específico
  static int xpForLevel(int level) {
    if (level <= 1) return 0;
    // Fórmula progressiva: level * 100 + (level - 1) * 50
    return (level * xpPerLevel) + ((level - 1) * 50);
  }
  
  /// Calcula XP total necessário até um nível
  static int totalXpForLevel(int level) {
    int total = 0;
    for (int i = 1; i <= level; i++) {
      total += xpForLevel(i);
    }
    return total;
  }
  
  // ============================================================================
  // ATRIBUTOS DO SISTEMA
  // ============================================================================
  
  static const List<String> attributes = [
    'disciplina',
    'evolucao',
    'estudo',
    'shape',
    'habito',
  ];
  
  static const Map<String, String> attributeNames = {
    'disciplina': 'Disciplina',
    'evolucao': 'Evolução',
    'estudo': 'Estudo',
    'shape': 'Shape',
    'habito': 'Hábito',
  };
  
  static const Map<String, String> attributeIcons = {
    'disciplina': '🎯',
    'evolucao': '⚡',
    'estudo': '📚',
    'shape': '💪',
    'habito': '🔥',
  };
  
  static const int maxAttributePoints = 100;
  
  // ============================================================================
  // MISSÕES
  // ============================================================================
  
  /// Tipos de missões
  static const String missionTypeFixed = 'fixed';
  static const String missionTypeSequence = 'sequence';
  
  /// Categorias de missões fixas
  static const List<String> fixedMissionCategories = [
    'ingles',
    'treino',
    'leitura',
    'estudo',
    'meditacao',
    'trabalho',
  ];
  
  static const Map<String, String> fixedMissionNames = {
    'ingles': 'Inglês',
    'treino': 'Treino',
    'leitura': 'Leitura',
    'estudo': 'Estudo',
    'meditacao': 'Meditação',
    'trabalho': 'Trabalho',
  };
  
  static const Map<String, String> fixedMissionIcons = {
    'ingles': '🗣️',
    'treino': '💪',
    'leitura': '📖',
    'estudo': '📝',
    'meditacao': '🧘',
    'trabalho': '💼',
  };
  
  // Recompensas padrão de missões
  static const int dailyMissionXp = 50;
  static const int sequenceMissionXp = 100;
  static const int bonusStreakXp = 25; // XP bônus por dia de sequência
  
  // ============================================================================
  // SEQUÊNCIAS (STREAKS)
  // ============================================================================
  
  static const int minimumStreakDays = 3; // Mínimo de dias para considerar uma sequência
  static const int streakResetHours = 24; // Horas até resetar a sequência
  
  /// Multiplicadores de XP baseado em sequência
  static double streakXpMultiplier(int streakDays) {
    if (streakDays < 7) return 1.0;
    if (streakDays < 14) return 1.2;
    if (streakDays < 30) return 1.5;
    if (streakDays < 60) return 2.0;
    return 2.5; // 60+ dias
  }
  
  // ============================================================================
  // SERVIDORES
  // ============================================================================
  
  static const int maxPlayersPerServer = 1000;
  static const int serverWarningCapacity = 900; // Aviso de servidor cheio
  
  /// Status de disponibilidade do servidor
  static String getServerStatus(int playerCount, int maxPlayers) {
    final percentage = (playerCount / maxPlayers) * 100;
    if (percentage >= 95) return 'CHEIO';
    if (percentage >= 80) return 'LOTADO';
    if (percentage >= 50) return 'ATIVO';
    return 'DISPONÍVEL';
  }
  
  // ============================================================================
  // FORMATAÇÃO
  // ============================================================================
  
  /// Formata números grandes (ex: 1000 -> 1k, 1000000 -> 1M)
  static String formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}k';
    }
    return number.toString();
  }
  
  /// Formata porcentagem
  static String formatPercentage(double value, {int decimals = 1}) {
    return '${value.toStringAsFixed(decimals)}%';
  }
  
  // ============================================================================
  // SAUDAÇÕES
  // ============================================================================
  
  /// Retorna saudação baseada na hora do dia
  static String getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Bom dia';
    if (hour < 18) return 'Boa tarde';
    return 'Boa noite';
  }
  
  // ============================================================================
  // FRASES MOTIVACIONAIS POR RANK
  // ============================================================================
  
  static const Map<String, List<String>> motivationalQuotes = {
    'E': [
      'Todo grande caçador começou do zero. Sua jornada épica começa agora!',
      'O caminho de mil léguas começa com um único passo.',
      'Grandes conquistas aguardam aqueles que perseveram.',
    ],
    'D': [
      'O primeiro passo foi dado. Agora, mostre do que você é capaz!',
      'Sua evolução começou. Continue firme em seu caminho.',
      'A jornada pode ser longa, mas você está progredindo.',
    ],
    'C': [
      'Você está evoluindo. Continue e alcance novos patamares!',
      'Seu esforço está sendo reconhecido. Siga em frente!',
      'Você superou as expectativas iniciais. Continue assim!',
    ],
    'B': [
      'Sua determinação está dando frutos. O poder está crescendo!',
      'Poucos chegam até aqui. Você está entre os fortes.',
      'Seu potencial começa a se revelar verdadeiramente.',
    ],
    'A': [
      'Poucos chegam até aqui. Você é extraordinário!',
      'Elite. Seu nome começará a ser conhecido.',
      'O poder que você conquistou impressiona a muitos.',
    ],
    'S': [
      'Elite entre os caçadores. Seu nome será lembrado!',
      'Lendário. Pouquíssimos alcançam este nível.',
      'Você transcendeu os limites comuns.',
    ],
    'SS': [
      'Lendário! Você transcendeu os limites humanos!',
      'Monarca em ascensão. O poder absoluto está próximo.',
      'Você está entre os deuses entre os mortais.',
    ],
    'SSS': [
      'MONARCA SUPREMO! Você alcançou o ápice absoluto!',
      'O poder absoluto está em suas mãos.',
      'Você atingiu o que poucos sonharam alcançar.',
    ],
  };
  
  /// Retorna uma frase motivacional aleatória para o rank
  static String getMotivationalQuote(String rank) {
    final quotes = motivationalQuotes[rank] ?? motivationalQuotes['E']!;
    return quotes[DateTime.now().millisecondsSinceEpoch % quotes.length];
  }
  
  // ============================================================================
  // TÍTULOS POR RANK
  // ============================================================================
  
  static const Map<String, String> rankTitles = {
    'E': 'CAÇADOR INICIANTE',
    'D': 'CAÇADOR NOVATO',
    'C': 'CAÇADOR COMPETENTE',
    'B': 'CAÇADOR EXPERIENTE',
    'A': 'CAÇADOR ELITE',
    'S': 'CAÇADOR LENDÁRIO',
    'SS': 'CAÇADOR SUPREMO',
    'SSS': 'MONARCA ABSOLUTO',
  };
  
  // ============================================================================
  // CONQUISTAS E BADGES
  // ============================================================================
  
  static const Map<String, String> achievementNames = {
    'first_mission': 'Primeira Missão',
    'week_streak': 'Guerreiro de 7 Dias',
    'month_streak': 'Incansável',
    'rank_up': 'Ascensão',
    'level_10': 'Veterano',
    'level_50': 'Mestre',
    'level_100': 'Lenda Viva',
  };
  
  // ============================================================================
  // ANIMAÇÕES E DURAÇÃO
  // ============================================================================
  
  static const Duration shortAnimation = Duration(milliseconds: 200);
  static const Duration mediumAnimation = Duration(milliseconds: 400);
  static const Duration longAnimation = Duration(milliseconds: 800);
  static const Duration welcomeAnimation = Duration(milliseconds: 3000);
  
  // ============================================================================
  // VALIDAÇÕES
  // ============================================================================
  
  static const int minUsernameLength = 3;
  static const int maxUsernameLength = 20;
  static const int minPasswordLength = 6;
  
  /// Valida username
  static String? validateUsername(String? value) {
    if (value == null || value.isEmpty) {
      return 'Digite um nome de usuário';
    }
    if (value.length < minUsernameLength) {
      return 'Mínimo de $minUsernameLength caracteres';
    }
    if (value.length > maxUsernameLength) {
      return 'Máximo de $maxUsernameLength caracteres';
    }
    // Apenas letras, números e underscore
    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(value)) {
      return 'Apenas letras, números e _';
    }
    return null;
  }
  
  /// Valida email
  static String? validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Digite um email';
    }
    // Regex básico de email
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
      return 'Email inválido';
    }
    return null;
  }
  
  /// Valida senha
  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Digite uma senha';
    }
    if (value.length < minPasswordLength) {
      return 'Mínimo de $minPasswordLength caracteres';
    }
    return null;
  }
  
  // ============================================================================
  // FIREBASE PATHS
  // ============================================================================
  
  static const String serversPath = 'servers';
  static const String userServersPath = 'userServers';
  static const String serverDataPath = 'serverData';
  static const String usersPath = 'users';
  static const String dailyMissionsPath = 'dailyMissions';
  static const String sequencesPath = 'sequences';
  static const String attributesPath = 'attributes';
  
  /// Constrói path para dados do usuário em um servidor
  static String getUserServerDataPath(String serverId, String userId) {
    return '$serverDataPath/$serverId/$usersPath/$userId';
  }
  
  /// Constrói path para missões diárias do usuário
  static String getDailyMissionsPath(String serverId, String userId, String date) {
    return '$serverDataPath/$serverId/$dailyMissionsPath/$userId/$date';
  }
  
  /// Constrói path para sequências do usuário
  static String getSequencesPath(String serverId, String userId) {
    return '$serverDataPath/$serverId/$sequencesPath/$userId';
  }
  
  // ============================================================================
  // CORES PADRÃO (caso rank_themes não esteja disponível)
  // ============================================================================
  
  static const Map<String, int> defaultRankColors = {
    'E': 0xFF9E9E9E,   // Cinza
    'D': 0xFF4CAF50,   // Verde
    'C': 0xFF2196F3,   // Azul
    'B': 0xFF9C27B0,   // Roxo
    'A': 0xFFFF9800,   // Laranja
    'S': 0xFFFFD700,   // Dourado
    'SS': 0xFF00E5FF,  // Ciano
    'SSS': 0xFFAA00FF, // Roxo Místico
  };
  
  // ============================================================================
  // MENSAGENS DO SISTEMA
  // ============================================================================
  
  static const String loadingMessage = 'Carregando...';
  static const String errorMessage = 'Ocorreu um erro. Tente novamente.';
  static const String successMessage = 'Operação realizada com sucesso!';
  static const String noInternetMessage = 'Sem conexão com a internet';
  
  // Mensagens de missões
  static const String missionCompletedMessage = 'Missão Completada! +50 XP';
  static const String streakBonusMessage = 'Bônus de Sequência! +';
  static const String levelUpMessage = 'LEVEL UP!';
  static const String rankUpMessage = 'RANK UP!';
  
  // ============================================================================
  // DEBUG
  // ============================================================================
  
  static const bool isDebugMode = true; // Altere para false em produção
  
  /// Log apenas se estiver em modo debug
  static void debugLog(String message) {
    if (isDebugMode) {
      print('[Monarch] $message');
    }
  }
}