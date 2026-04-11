import 'package:shared_preferences/shared_preferences.dart';
import 'package:monarch/models/user_model.dart';

// =============================================================================
// SERVIÇO DE BOAS-VINDAS DO RANKING
// =============================================================================

/// Controla a exibição do popup de boas-vindas na tela de ranking.
///
/// Usa [SharedPreferences] para garantir que o popup seja mostrado
/// apenas na primeira vez que o usuário acessa o ranking.
class RankingWelcomeService {
  static const String _keyWelcomeShown = 'ranking_welcome_shown_v2';

  /// Retorna `true` se o popup de boas-vindas deve ser mostrado.
  ///
  /// Marca automaticamente como mostrado ao retornar `true`.
  static Future<bool> shouldShowWelcome() async {
    final prefs = await SharedPreferences.getInstance();
    final hasShown = prefs.getBool(_keyWelcomeShown) ?? false;
    if (!hasShown) {
      await prefs.setBool(_keyWelcomeShown, true);
      return true;
    }
    return false;
  }
}

// =============================================================================
// HELPERS DE SERIALIZAÇÃO DO RANKING
// =============================================================================

/// Converte um [UserModel] para JSON incluindo o ID como campo.
Map<String, dynamic> userToJson(UserModel u) => {'id': u.id, ...u.toMap()};

/// Reconstrói um [UserModel] a partir de um mapa JSON com campo 'id'.
UserModel userFromJson(dynamic e) {
  final map = e as Map<String, dynamic>;
  final id = map['id']?.toString() ?? '';
  return UserModel.fromMap(id, map);
}

/// Serializa uma lista de [UserModel] para JSON (usado pelo [CacheService]).
List<Map<String, dynamic>> usersToEncodable(List<UserModel>? list) =>
    list?.map(userToJson).toList() ?? [];

/// Deserializa uma lista JSON de volta para [UserModel] (usado pelo [CacheService]).
List<UserModel> usersFromJson(dynamic json) =>
    (json as List).map(userFromJson).toList();
