/// Modelos de missões do sistema Dracoryx.
///
/// Define os tipos de missão (fixa e customizada), recorrência semanal,
/// estado diário, cálculo de XP e sugestões de missões predefinidas.
library;

import 'package:monarch/services/database_service.dart';

/// Tipos de missão disponíveis no sistema.
///
/// - [fixed]: missões obrigatórias para manter o streak diário.
/// - [custom]: missões criadas pelo usuário para evolução pessoal.
enum MissionType {
  fixed,
  custom,
}

/// Categorias de missões customizadas.
///
/// Determina qual atributo é incrementado ao completar a missão:
/// - [study]: incrementa Estudo
/// - [fitness]: incrementa Shape
/// - [habit]: incrementa Hábito
/// - [other]: sem atributo específico, concede apenas XP
enum CustomMissionCategory {
  study,
  fitness,
  habit,
  other,
}

// =============================================================================
// RECORRÊNCIA
// =============================================================================

/// Tipo de período de recorrência para missões fixas.
///
/// - [forever]: recorre indefinidamente
/// - [weeks]: recorre por N semanas
/// - [months]: recorre por N meses
enum RecurrencePeriodType {
  forever,
  weeks,
  months,
}

/// Configuração de recorrência semanal para missões fixas.
///
/// Define em quais dias da semana a missão aparece e por quanto
/// tempo ela permanece ativa (para sempre, N semanas ou N meses).
class MissionRecurrence {
  /// Dias da semana ativos: 0=Seg, 1=Ter, 2=Qua, 3=Qui, 4=Sex, 5=Sáb, 6=Dom
  final List<int> weekdays;
  final RecurrencePeriodType periodType;
  final int? periodValue;
  final DateTime startDate;
  final DateTime? endDate;

  MissionRecurrence({
    required this.weekdays,
    required this.periodType,
    this.periodValue,
    required this.startDate,
    this.endDate,
  });

  /// Verifica se a missão deve aparecer hoje (usa DatabaseService.now).
  bool isActiveToday() => isActiveOn(DatabaseService.now);

  /// Verifica se a missão deve aparecer em [date].
  ///
  /// Regras:
  ///   1. date >= startDate (não aparece antes de ser criada)
  ///   2. date <= endDate   (não aparece após o prazo)
  ///   3. O dia da semana de [date] está na lista weekdays
  bool isActiveOn(DateTime date) {
    final dateOnly = DateTime(date.year, date.month, date.day);

    // 1. Antes da data de início → não aparece
    final startOnly =
        DateTime(startDate.year, startDate.month, startDate.day);
    if (dateOnly.isBefore(startOnly)) return false;

    // 2. Após a data de término → não aparece
    if (endDate != null) {
      final endOnly =
          DateTime(endDate!.year, endDate!.month, endDate!.day);
      if (dateOnly.isAfter(endOnly)) return false;
    }

    // 3. Dia da semana
    // Dart weekday: 1=Seg ... 7=Dom  →  nosso índice: 0=Seg ... 6=Dom
    final dayIndex = date.weekday - 1;
    return weekdays.contains(dayIndex);
  }

  /// Calcula a data final da recorrência baseado no tipo e valor.
  ///
  /// Retorna `null` para recorrência infinita ([RecurrencePeriodType.forever]).
  static DateTime? calculateEndDate({
    required RecurrencePeriodType type,
    required DateTime startDate,
    int? value,
  }) {
    if (type == RecurrencePeriodType.forever) return null;
    if (value == null || value <= 0) return null;
    if (type == RecurrencePeriodType.weeks) {
      return startDate.add(Duration(days: value * 7));
    }
    if (type == RecurrencePeriodType.months) {
      return DateTime(
          startDate.year, startDate.month + value, startDate.day);
    }
    return null;
  }

  /// Converte a recorrência para Map para persistência no Firebase.
  Map<String, dynamic> toMap() {
    return {
      'weekdays': weekdays,
      'periodType': periodType.name,
      if (periodValue != null) 'periodValue': periodValue,
      'startDate': startDate.millisecondsSinceEpoch,
      if (endDate != null) 'endDate': endDate!.millisecondsSinceEpoch,
    };
  }

  /// Cria [MissionRecurrence] a partir de um Map do Firebase.
  factory MissionRecurrence.fromMap(Map<String, dynamic> map) {
    final weekdays = (map['weekdays'] as List?)
            ?.map((e) => (e as num).toInt())
            .toList() ??
        [];

    RecurrencePeriodType periodType;
    switch (map['periodType'] as String?) {
      case 'weeks':
        periodType = RecurrencePeriodType.weeks;
        break;
      case 'months':
        periodType = RecurrencePeriodType.months;
        break;
      default:
        periodType = RecurrencePeriodType.forever;
    }

    DateTime? endDate;
    if (map['endDate'] != null) {
      endDate = DateTime.fromMillisecondsSinceEpoch(
          (map['endDate'] as num).toInt());
    }

    return MissionRecurrence(
      weekdays: weekdays,
      periodType: periodType,
      periodValue: map['periodValue'] != null
          ? (map['periodValue'] as num).toInt()
          : null,
      startDate: DateTime.fromMillisecondsSinceEpoch(
          (map['startDate'] as num).toInt()),
      endDate: endDate,
    );
  }

  /// Rótulo legível do período de recorrência (ex: 'Para sempre', '4x semanas').
  String get periodLabel {
    switch (periodType) {
      case RecurrencePeriodType.forever:
        return 'Para sempre';
      case RecurrencePeriodType.weeks:
        return '${periodValue}x semanas';
      case RecurrencePeriodType.months:
        return '${periodValue}x meses';
    }
  }

  /// Rótulo legível dos dias da semana ativos (ex: 'Todos os dias', 'Dias úteis').
  String get weekdaysLabel {
    const names = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'];
    if (weekdays.length == 7) return 'Todos os dias';
    if (weekdays.length == 5 &&
        !weekdays.contains(5) &&
        !weekdays.contains(6)) {
      return 'Dias úteis';
    }
    return weekdays.map((d) => names[d]).join(', ');
  }
}

// =============================================================================
// MISSION MODEL
// =============================================================================

/// Modelo de uma missão individual do sistema Dracoryx.
///
/// Pode ser do tipo [MissionType.fixed] (obrigatória, afeta streak)
/// ou [MissionType.custom] (opcional, foco em evolução pessoal).
/// Missões fixas podem ter [MissionRecurrence] para recorrência semanal.
class MissionModel {
  final String id;
  final String name;
  final int xp;
  final bool completed;
  final DateTime? completedAt;
  final MissionType type;
  final CustomMissionCategory? category;
  final MissionRecurrence? recurrence;

  MissionModel({
    required this.id,
    required this.name,
    required this.xp,
    this.completed = false,
    this.completedAt,
    required this.type,
    this.category,
    this.recurrence,
  });

  /// Cria [MissionModel] a partir de um Map do Firebase.
  ///
  /// O [type] determina se a missão é fixa ou customizada,
  /// o que influencia o parsing de campos como 'category' e 'recurrence'.
  factory MissionModel.fromMap(
      String id, Map<String, dynamic> map, MissionType type) {
    CustomMissionCategory? category;
    if (type == MissionType.custom && map.containsKey('category')) {
      category =
          _parseCategoryFromString(map['category'] as String?);
    }

    MissionRecurrence? recurrence;
    if (type == MissionType.fixed &&
        map.containsKey('recurrence') &&
        map['recurrence'] is Map) {
      try {
        recurrence = MissionRecurrence.fromMap(
          Map<String, dynamic>.from(map['recurrence'] as Map),
        );
      } catch (_) {}
    }

    return MissionModel(
      id: id,
      name: map['name']?.toString() ?? '',
      xp: _parseInt(map['xp']) ?? 0,
      completed: map['completed'] == true,
      completedAt: _parseDateTime(map['completedAt']),
      type: type,
      category: category,
      recurrence: recurrence,
    );
  }

  /// Converte um valor dinâmico para [int].
  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  /// Converte um valor dinâmico para [DateTime] (nullable).
  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    try {
      if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
      if (value is String) return DateTime.parse(value);
    } catch (_) {}
    return null;
  }

  /// Converte uma string de categoria para [CustomMissionCategory].
  ///
  /// Aceita nomes em português e inglês. Retorna [CustomMissionCategory.other]
  /// como fallback.
  static CustomMissionCategory _parseCategoryFromString(String? str) {
    if (str == null) return CustomMissionCategory.other;
    switch (str.toLowerCase()) {
      case 'study':
      case 'estudo':
        return CustomMissionCategory.study;
      case 'fitness':
      case 'treino':
      case 'shape':
        return CustomMissionCategory.fitness;
      case 'habit':
      case 'habito':
      case 'hábito':
        return CustomMissionCategory.habit;
      default:
        return CustomMissionCategory.other;
    }
  }

  /// Converte a missão para Map para persistência no Firebase.
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'name': name,
      'xp': xp,
      'completed': completed,
      if (completedAt != null)
        'completedAt': completedAt!.millisecondsSinceEpoch,
    };

    if (type == MissionType.custom && category != null) {
      map['category'] = category.toString().split('.').last;
    }

    if (type == MissionType.fixed && recurrence != null) {
      map['recurrence'] = recurrence!.toMap();
    }

    return map;
  }

  /// Cria uma cópia do [MissionModel] com os campos alterados.
  MissionModel copyWith({
    String? name,
    int? xp,
    bool? completed,
    DateTime? completedAt,
    CustomMissionCategory? category,
    MissionRecurrence? recurrence,
  }) {
    return MissionModel(
      id: id,
      name: name ?? this.name,
      xp: xp ?? this.xp,
      completed: completed ?? this.completed,
      completedAt: completedAt ?? this.completedAt,
      type: type,
      category: category ?? this.category,
      recurrence: recurrence ?? this.recurrence,
    );
  }

  // =========================================================================
  // HELPERS
  // =========================================================================

  /// Retorna `true` se esta é uma missão fixa (obrigatória).
  bool get isFixed => type == MissionType.fixed;

  /// Retorna `true` se esta é uma missão customizada (opcional).
  bool get isCustom => type == MissionType.custom;

  /// Verifica se esta missão deve aparecer hoje (usa DatabaseService.now).
  bool get isActiveToday {
    if (!isFixed || recurrence == null) return true;
    return recurrence!.isActiveToday();
  }

  /// Retorna `true` se a missão é classificada como estudo.
  bool get isStudyMission =>
      category == CustomMissionCategory.study ||
      _containsStudyKeywords(name);

  /// Retorna `true` se a missão é classificada como fitness.
  bool get isFitnessMission =>
      category == CustomMissionCategory.fitness ||
      _containsFitnessKeywords(name);

  /// Retorna `true` se a missão é classificada como hábito.
  bool get isHabitMission => category == CustomMissionCategory.habit;

  /// Retorna `true` se a missão fixa possui recorrência configurada.
  bool get hasRecurrence => isFixed && recurrence != null;

  /// Verifica se o nome da missão contém palavras-chave de estudo.
  static bool _containsStudyKeywords(String name) {
    const keywords = [
      'estudo', 'estudar', 'ler', 'leitura', 'livro', 'curso',
      'aula', 'aprender', 'revisar', 'revisão', 'pesquisar',
      'study', 'read', 'book', 'course', 'learn', 'review',
    ];
    final lower = name.toLowerCase();
    return keywords.any((k) => lower.contains(k));
  }

  /// Verifica se o nome da missão contém palavras-chave de fitness.
  static bool _containsFitnessKeywords(String name) {
    const keywords = [
      'treino', 'treinar', 'academia', 'exercício', 'malhar',
      'corrida', 'correr', 'natação', 'nadar', 'yoga', 'alongamento',
      'workout', 'gym', 'exercise', 'run', 'swim', 'fitness',
    ];
    final lower = name.toLowerCase();
    return keywords.any((k) => lower.contains(k));
  }

  @override
  String toString() =>
      'Mission(id: $id, name: $name, type: $type, completed: $completed)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MissionModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

// =============================================================================
// ESTADO DAS MISSÕES DO DIA
// =============================================================================

/// Estado agregado das missões de um dia específico.
///
/// Fornece contagens de progresso, flags de conclusão e percentuais
/// para missões fixas e customizadas separadamente.
class DailyMissionsState {
  final List<MissionModel> fixedMissions;
  final List<MissionModel> customMissions;
  final DateTime date;

  DailyMissionsState({
    required this.fixedMissions,
    required this.customMissions,
    required this.date,
  });

  int get totalMissions => fixedMissions.length + customMissions.length;
  int get completedMissions =>
      fixedMissions.where((m) => m.completed).length +
      customMissions.where((m) => m.completed).length;

  int get fixedCompleted => fixedMissions.where((m) => m.completed).length;
  int get fixedTotal => fixedMissions.length;
  int get customCompleted => customMissions.where((m) => m.completed).length;
  int get customTotal => customMissions.length;

  bool get allFixedCompleted =>
      fixedMissions.isNotEmpty && fixedMissions.every((m) => m.completed);

  bool get allCustomCompleted =>
      customMissions.isNotEmpty && customMissions.every((m) => m.completed);

  bool get allDailyCompleted => allFixedCompleted && allCustomCompleted;
  bool get reached3CustomBonus => customCompleted >= 3;
  bool get reachedAllCustomBonus => allCustomCompleted;

  double get progressPercentage =>
      totalMissions > 0 ? (completedMissions / totalMissions) : 0.0;

  double get fixedProgressPercentage =>
      fixedTotal > 0 ? (fixedCompleted / fixedTotal) : 0.0;

  double get customProgressPercentage =>
      customTotal > 0 ? (customCompleted / customTotal) : 0.0;
}

// =============================================================================
// XP CALCULATOR
// =============================================================================

/// Calculadora centralizada de XP do sistema de progressão.
///
/// Define fórmulas para XP de missões, XP necessário por nível,
/// bônus de streak e penalidade por missões incompletas.
class XpCalculator {
  /// Calcula XP ganho ao completar uma missão fixa, escala com o nível.
  static int fixedMissionXp(int userLevel) => 50 + (userLevel * 10);

  /// Calcula XP ganho ao completar uma missão customizada, escala com o nível.
  static int customMissionXp(int userLevel) => 30 + (userLevel * 5);

  /// Calcula XP necessário para alcançar um nível específico.
  static int xpForLevel(int level) {
    if (level <= 1) return 0;
    return (level * 100) + ((level - 1) * 25);
  }

  /// Calcula XP total acumulado necessário até um nível.
  static int totalXpForLevel(int level) {
    int total = 0;
    for (int i = 1; i <= level; i++) {
      total += xpForLevel(i);
    }
    return total;
  }

  /// Bônus de XP baseado nos dias consecutivos de streak.
  static int streakBonus(int streakDays) {
    if (streakDays < 3) return 0;
    if (streakDays < 7) return 25;
    if (streakDays < 14) return 50;
    if (streakDays < 30) return 100;
    return 150;
  }

  /// Penalidade de XP por missões fixas incompletas.
  static int incompletePenalty(int userLevel, int incompleteMissions) {
    final penaltyPerMission =
        (fixedMissionXp(userLevel) * 0.4).toInt();
    return penaltyPerMission * incompleteMissions;
  }
}

// =============================================================================
// SUGESTÕES DE MISSÕES
// =============================================================================

/// Sugestão de missão predefinida para apresentar ao usuário.
///
/// Usada na tela de criação de missões para oferecer ideias
/// categorizadas com emoji representativo.
class MissionSuggestion {
  final String name;
  final String category;
  final String emoji;
  final MissionType type;

  const MissionSuggestion({
    required this.name,
    required this.category,
    required this.emoji,
    required this.type,
  });
}

/// Repositório estático de sugestões de missões predefinidas.
///
/// Organizado por categorias: Fitness, Estudos, Saúde, Higiene e Nutrição.
class MissionSuggestions {
  /// Lista completa de todas as sugestões de missões disponíveis.
  static const List<MissionSuggestion> all = [
    // FITNESS
    MissionSuggestion(name: 'Treinar na academia', category: 'Fitness', emoji: '🏋️', type: MissionType.fixed),
    MissionSuggestion(name: 'Correr 30 minutos', category: 'Fitness', emoji: '🏃', type: MissionType.fixed),
    MissionSuggestion(name: 'Fazer 50 flexões', category: 'Fitness', emoji: '💪', type: MissionType.custom),
    MissionSuggestion(name: 'Alongamento matinal', category: 'Fitness', emoji: '🧘', type: MissionType.fixed),
    MissionSuggestion(name: '10.000 passos no dia', category: 'Fitness', emoji: '👟', type: MissionType.fixed),
    MissionSuggestion(name: 'Treino de calistenia', category: 'Fitness', emoji: '🤸', type: MissionType.custom),
    MissionSuggestion(name: 'Nadar por 45 min', category: 'Fitness', emoji: '🏊', type: MissionType.custom),
    MissionSuggestion(name: 'Yoga ou meditação', category: 'Fitness', emoji: '🧘', type: MissionType.fixed),

    // ESTUDOS
    MissionSuggestion(name: 'Estudar inglês 30 min', category: 'Estudos', emoji: '🇺🇸', type: MissionType.fixed),
    MissionSuggestion(name: 'Ler 20 páginas do livro', category: 'Estudos', emoji: '📖', type: MissionType.fixed),
    MissionSuggestion(name: 'Fazer curso online 1h', category: 'Estudos', emoji: '💻', type: MissionType.custom),
    MissionSuggestion(name: 'Revisar anotações', category: 'Estudos', emoji: '📝', type: MissionType.fixed),
    MissionSuggestion(name: 'Estudar programação 1h', category: 'Estudos', emoji: '👨‍💻', type: MissionType.custom),
    MissionSuggestion(name: 'Assistir documentário educativo', category: 'Estudos', emoji: '🎓', type: MissionType.custom),
    MissionSuggestion(name: 'Aprender novo vocabulário', category: 'Estudos', emoji: '📚', type: MissionType.fixed),
    MissionSuggestion(name: 'Resolver exercícios de matemática', category: 'Estudos', emoji: '🔢', type: MissionType.custom),

    // SAÚDE
    MissionSuggestion(name: 'Beber 2L de água', category: 'Saúde', emoji: '💧', type: MissionType.fixed),
    MissionSuggestion(name: 'Dormir às 23h', category: 'Saúde', emoji: '😴', type: MissionType.fixed),
    MissionSuggestion(name: 'Meditar 10 minutos', category: 'Saúde', emoji: '🧠', type: MissionType.fixed),
    MissionSuggestion(name: 'Evitar açúcar hoje', category: 'Saúde', emoji: '🚫', type: MissionType.fixed),
    MissionSuggestion(name: 'Tomar vitaminas', category: 'Saúde', emoji: '💊', type: MissionType.fixed),
    MissionSuggestion(name: 'Fazer check-up médico', category: 'Saúde', emoji: '🏥', type: MissionType.custom),
    MissionSuggestion(name: 'Respiração profunda 5 min', category: 'Saúde', emoji: '🌬️', type: MissionType.fixed),

    // HIGIENE
    MissionSuggestion(name: 'Skincare completo', category: 'Higiene', emoji: '🧴', type: MissionType.fixed),
    MissionSuggestion(name: 'Escovar dentes 3x', category: 'Higiene', emoji: '🦷', type: MissionType.fixed),
    MissionSuggestion(name: 'Usar fio dental', category: 'Higiene', emoji: '🦷', type: MissionType.fixed),
    MissionSuggestion(name: 'Aplicar protetor solar', category: 'Higiene', emoji: '☀️', type: MissionType.fixed),

    // NUTRIÇÃO
    MissionSuggestion(name: 'Comer 5 porções de fruta/veg', category: 'Nutrição', emoji: '🥗', type: MissionType.fixed),
    MissionSuggestion(name: 'Preparar marmita saudável', category: 'Nutrição', emoji: '🍱', type: MissionType.custom),
    MissionSuggestion(name: 'Sem fast food hoje', category: 'Nutrição', emoji: '🚫', type: MissionType.fixed),
    MissionSuggestion(name: 'Tomar café da manhã', category: 'Nutrição', emoji: '🌅', type: MissionType.fixed),
    MissionSuggestion(name: 'Registrar calorias do dia', category: 'Nutrição', emoji: '📊', type: MissionType.custom),

    // PRODUTIVIDADE
    MissionSuggestion(name: 'Acordar às 6h', category: 'Produtividade', emoji: '⏰', type: MissionType.fixed),
    MissionSuggestion(name: 'Planejar o dia (to-do list)', category: 'Produtividade', emoji: '📋', type: MissionType.fixed),
    MissionSuggestion(name: 'Sem redes sociais até 9h', category: 'Produtividade', emoji: '📵', type: MissionType.fixed),
    MissionSuggestion(name: 'Organizar o quarto', category: 'Produtividade', emoji: '🏠', type: MissionType.custom),
    MissionSuggestion(name: 'Ler e-mails e responder', category: 'Produtividade', emoji: '📧', type: MissionType.custom),
    MissionSuggestion(name: '2h de deep work sem celular', category: 'Produtividade', emoji: '🎯', type: MissionType.fixed),
    MissionSuggestion(name: 'Revisar metas semanais', category: 'Produtividade', emoji: '🗓️', type: MissionType.custom),
    MissionSuggestion(name: 'Limpar área de trabalho', category: 'Produtividade', emoji: '🧹', type: MissionType.custom),
  ];

  static List<MissionSuggestion> byCategory(String category) =>
      all.where((s) => s.category == category).toList();

  static List<MissionSuggestion> byType(MissionType type) =>
      all.where((s) => s.type == type).toList();

  static List<String> get categories =>
      all.map((s) => s.category).toSet().toList();
}
