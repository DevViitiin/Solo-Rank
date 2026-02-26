class UserModel {
  final String id;
  final String name;
  final String email;
  final String rank;
  final int level;
  final int xp;
  final int totalXp;
  final DateTime createdAt;
  final DateTime lastSeen;
  final UserStats stats;
  final bool terms;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.rank,
    required this.level,
    required this.xp,
    required this.totalXp,
    required this.createdAt,
    required this.lastSeen,
    required this.stats,
    required this.terms,
  });

  /// Cria um novo usuário com valores padrão
  factory UserModel.newUser({
    required String id,
    required String name,
    required String email,
    required bool terms, 
  }) {
    final now = DateTime.now();
    return UserModel(
      id: id,
      name: name,
      email: email,
      rank: 'E', // Todos começam no rank E
      level: 1,
      xp: 0,
      totalXp: 0,
      createdAt: now,
      terms: terms, // 
      lastSeen: now,
      stats: UserStats.initial(),
    );
  }

  /// Converte para Map para salvar no Firebase
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'rank': rank,
      'level': level,
      'xp': xp,
      'totalXp': totalXp,
      'createdAt': createdAt.toIso8601String(),
      'lastSeen': lastSeen.toIso8601String(),
      'terms': terms, // 
      'stats': stats.toMap(),
    };
  }

  /// Cria UserModel a partir de Map do Firebase
  factory UserModel.fromMap(String id, Map<String, dynamic> map) {
    try {
      return UserModel(
        id: id,
        name: map['name']?.toString() ?? '',
        email: map['email']?.toString() ?? '',
        rank: map['rank']?.toString() ?? 'E',
        terms: map['terms'] == true, 
        level: _parseInt(map['level']) ?? 1,
        xp: _parseInt(map['xp']) ?? 0,
        totalXp: _parseInt(map['totalXp']) ?? 0,
        createdAt: _parseDateTime(map['createdAt']),
        lastSeen: _parseDateTime(map['lastSeen']),
        stats: map['stats'] != null && map['stats'] is Map
            ? UserStats.fromMap(Map<String, dynamic>.from(map['stats'] as Map))
            : UserStats.initial(),
      );
    } catch (e) {
      print('Erro ao criar UserModel: $e');
      // Retorna um usuário padrão em caso de erro
      final now = DateTime.now();
      return UserModel(
        id: id,
        name: 'Jogador',
        email: '',
        rank: 'E',
        level: 1,
        xp: 0,
        totalXp: 0,
        createdAt: now,
        terms: false,
        lastSeen: now,
        stats: UserStats.initial(),
      );
    }
  }

  /// Converte valor para int de forma segura
  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  /// Converte valor para DateTime de forma segura
  static DateTime _parseDateTime(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (e) {
        return DateTime.now();
      }
    }
    return DateTime.now();
  }

  /// Copia o modelo com alterações
  UserModel copyWith({
    String? name,
    String? email,
    String? rank,
    int? level,
    int? xp,
    int? totalXp,
    DateTime? createdAt,
    DateTime? lastSeen,
    UserStats? stats,
    bool? terms,
  }) {
    return UserModel(
      id: id,
      name: name ?? this.name,
      email: email ?? this.email,
      rank: rank ?? this.rank,
      terms: terms ?? this.terms, 
      level: level ?? this.level,
      xp: xp ?? this.xp,
      totalXp: totalXp ?? this.totalXp,
      createdAt: createdAt ?? this.createdAt,
      lastSeen: lastSeen ?? this.lastSeen,
      stats: stats ?? this.stats,
    );
  }
}

/// Estatísticas do usuário
class UserStats {
  final int currentStreak;
  final int bestStreak;
  final int totalMissionsCompleted;
  final UserAttributes attributes;

  UserStats({
    required this.currentStreak,
    required this.bestStreak,
    required this.totalMissionsCompleted,
    required this.attributes,
  });

  /// Estatísticas iniciais
  factory UserStats.initial() {
    return UserStats(
      currentStreak: 0,
      bestStreak: 0,
      totalMissionsCompleted: 0,
      attributes: UserAttributes.initial(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'currentStreak': currentStreak,
      'bestStreak': bestStreak,
      'totalMissionsCompleted': totalMissionsCompleted,
      'attributes': attributes.toMap(),
    };
  }

  factory UserStats.fromMap(Map<String, dynamic> map) {
    try {
      return UserStats(
        currentStreak: _parseInt(map['currentStreak']) ?? 0,
        bestStreak: _parseInt(map['bestStreak']) ?? 0,
        totalMissionsCompleted: _parseInt(map['totalMissionsCompleted']) ?? 0,
        attributes: map['attributes'] != null && map['attributes'] is Map
            ? UserAttributes.fromMap(
                Map<String, dynamic>.from(map['attributes'] as Map))
            : UserAttributes.initial(),
      );
    } catch (e) {
      return UserStats.initial();
    }
  }

  static int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  UserStats copyWith({
    int? currentStreak,
    int? bestStreak,
    int? totalMissionsCompleted,
    UserAttributes? attributes,
  }) {
    return UserStats(
      currentStreak: currentStreak ?? this.currentStreak,
      bestStreak: bestStreak ?? this.bestStreak,
      totalMissionsCompleted:
          totalMissionsCompleted ?? this.totalMissionsCompleted,
      attributes: attributes ?? this.attributes,
    );
  }
}

/// Atributos do usuário
class UserAttributes {
  final int study;
  final int discipline;
  final int evolution;
  final int shape;
  final int habit;

  UserAttributes({
    required this.study,
    required this.discipline,
    required this.evolution,
    required this.shape,
    required this.habit,
  });

  factory UserAttributes.initial() {
    return UserAttributes(
      study: 0,
      discipline: 0,
      evolution: 0,
      shape: 0,
      habit: 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'study': study,
      'discipline': discipline,
      'evolution': evolution,
      'shape': shape,
      'habit': habit,
    };
  }

  factory UserAttributes.fromMap(Map<String, dynamic> map) {
    try {
      return UserAttributes(
        study: _parseInt(map['study']) ?? 0,
        discipline: _parseInt(map['discipline']) ?? 0,
        evolution: _parseInt(map['evolution']) ?? 0,
        shape: _parseInt(map['shape']) ?? 0,
        habit: _parseInt(map['habit']) ?? 0,
      );
    } catch (e) {
      return UserAttributes.initial();
    }
  }

  static int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  UserAttributes copyWith({
    int? study,
    int? discipline,
    int? evolution,
    int? shape,
    int? habit,
  }) {
    return UserAttributes(
      study: study ?? this.study,
      discipline: discipline ?? this.discipline,
      evolution: evolution ?? this.evolution,
      shape: shape ?? this.shape,
      habit: habit ?? this.habit,
    );
  }

  /// Retorna o total de pontos de atributos
  int get totalPoints =>
      study + discipline + evolution + shape + habit;

  /// Retorna um Map para facilitar acesso por nome
  Map<String, int> toAttributeMap() {
    return {
      'study': study,
      'discipline': discipline,
      'evolution': evolution,
      'shape': shape,
      'habit': habit,
    };
  }
}