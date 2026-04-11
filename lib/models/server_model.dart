/// Modelo de servidor multiplayer do sistema Dracoryx.
///
/// Cada servidor possui capacidade limitada de jogadores e pode estar
/// nos estados: 'active', 'full', ou 'closed'. Os jogadores competem
/// no ranking dentro do seu servidor.
class ServerModel {
  final String id;
  final String name;
  final String displayName;
  final int playerCount;
  final int maxPlayers;
  final String status;
  final DateTime openDate;

  ServerModel({
    required this.id,
    required this.name,
    required this.displayName,
    required this.playerCount,
    required this.maxPlayers,
    required this.status,
    required this.openDate,
  });

  /// Verifica se o servidor pode receber novos jogadores
  bool get canJoin => status == 'active' && playerCount < maxPlayers;

  /// Percentual de ocupação do servidor (com proteção contra divisão por zero)
  double get occupancyPercentage {
    if (maxPlayers == 0) return 0.0;
    return ((playerCount / maxPlayers) * 100).clamp(0.0, 100.0);
  }

  /// Converte para Map para salvar no Firebase
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'maxPlayers': maxPlayers,
      'playerCount': playerCount,
      'status': status,
      'openDate': openDate.toIso8601String(),
    };
  }

  /// Cria ServerModel a partir de Map do Firebase
  factory ServerModel.fromMap(String id, Map<String, dynamic> map) {
    final playerCount = _parseInt(map['playerCount']) ?? 0;
    final maxPlayers = _parseInt(map['maxPlayers']) ?? 1000;
    
    return ServerModel(
      id: id,
      name: map['name'] ?? '',
      displayName: map['name'] ?? '',
      playerCount: playerCount,
      maxPlayers: maxPlayers,
      status: map['status'] ?? 'active',
      openDate: _parseDateTime(map['openDate']),
    );
  }

  /// Converte um valor dinâmico para [int], retornando 0 como fallback.
  static int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  /// Converte um valor dinâmico para [DateTime].
  ///
  /// Aceita strings ISO 8601. Retorna [DateTime.now] como fallback.
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

  /// Cria uma cópia do [ServerModel] com os campos alterados.
  ServerModel copyWith({
    String? name,
    String? displayName,
    int? playerCount,
    int? maxPlayers,
    String? status,
    DateTime? openDate,
  }) {
    return ServerModel(
      id: id,
      name: name ?? this.name,
      displayName: displayName ?? this.displayName,
      playerCount: playerCount ?? this.playerCount,
      maxPlayers: maxPlayers ?? this.maxPlayers,
      status: status ?? this.status,
      openDate: openDate ?? this.openDate,
    );
  }
}
