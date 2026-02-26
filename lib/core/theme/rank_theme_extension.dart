import 'package:monarch/core/theme/rank_themes.dart';

/// Extensão para facilitar acesso aos temas por rank
extension RankThemesExtension on RankThemes {
  static RankTheme getTheme(String rank) {
    return RankThemes.getTheme(rank);
  }
}

