import 'package:shared_preferences/shared_preferences.dart';
import 'package:monarch/models/user_model.dart';

// =============================================================================
// SERVIÇO DE BOAS-VINDAS DO RANKING
// =============================================================================

class RankingWelcomeService {
  static const String _keyWelcomeShown = 'ranking_welcome_shown_v2';

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

Map<String, dynamic> userToJson(UserModel u) => {'id': u.id, ...u.toMap()};

UserModel userFromJson(dynamic e) {
  final map = e as Map<String, dynamic>;
  final id = map['id']?.toString() ?? '';
  return UserModel.fromMap(id, map);
}

List<Map<String, dynamic>> usersToEncodable(List<UserModel>? list) =>
    list?.map(userToJson).toList() ?? [];

List<UserModel> usersFromJson(dynamic json) =>
    (json as List).map(userFromJson).toList();
