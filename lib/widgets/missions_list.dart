import 'package:flutter/material.dart';
import 'package:monarch/core/theme/rank_themes.dart';
import 'package:monarch/models/mission_model.dart';

/// Widget de lista de missões com seções separadas.
///
/// Exibe missões em duas seções visuais distintas:
/// - **Missões Fixas**: obrigatórias para manter o streak diário.
///   Mostra progresso, recompensas e banner de conclusão.
/// - **Missões Customizadas**: criadas pelo usuário para evolução.
///   Mostra progresso de bônus (3+ e todas completas).
///
/// Cada missão exibe nome, tipo, categoria, XP e checkbox.
class MissionsListWidget extends StatelessWidget {
  final List<MissionModel> fixedMissions;
  final List<MissionModel> customMissions;
  final RankTheme theme;
  final Function(MissionModel) onToggleMission;
  final bool isLoading;
  
  const MissionsListWidget({
    Key? key,
    required this.fixedMissions,
    required this.customMissions,
    required this.theme,
    required this.onToggleMission,
    this.isLoading = false,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ===================================================================
          // SEÇÃO: MISSÕES FIXAS
          // ===================================================================
          _buildFixedMissionsSection(),
          
          const SizedBox(height: 24),
          
          // ===================================================================
          // SEÇÃO: MISSÕES CUSTOMIZADAS
          // ===================================================================
          _buildCustomMissionsSection(),
          
          const SizedBox(height: 80), // Espaço para bottom navigation
        ],
      ),
    );
  }
  
  // ===========================================================================
  // SEÇÃO DE MISSÕES FIXAS
  // ===========================================================================
  
  /// Constrói a seção de missões fixas com header, recompensas e lista.
  Widget _buildFixedMissionsSection() {
    final completedCount = fixedMissions.where((m) => m.completed).length;
    final totalCount = fixedMissions.length;
    final allCompleted = completedCount == totalCount && totalCount > 0;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: allCompleted ? theme.success : theme.primary.withOpacity(0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: (allCompleted ? theme.success : theme.primary).withOpacity(0.2),
            blurRadius: 12,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.primary.withOpacity(0.2),
                  theme.accent.withOpacity(0.1),
                ],
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(14),
                topRight: Radius.circular(14),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.stars_rounded,
                  color: theme.primary,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Missões Fixas',
                        style: TextStyle(
                          color: theme.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Complete todas para manter o streak',
                        style: TextStyle(
                          color: theme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildProgressBadge(completedCount, totalCount, allCompleted),
              ],
            ),
          ),
          
          // Recompensas
          if (!allCompleted) _buildFixedRewardsInfo(),
          
          // Lista de missões
          if (fixedMissions.isEmpty)
            _buildEmptyState('Nenhuma missão fixa hoje')
          else
            ...fixedMissions.map((mission) => _buildMissionTile(mission)),
          
          // Status de conclusão
          if (allCompleted) _buildCompletionBanner(isFixed: true),
        ],
      ),
    );
  }
  
  // ===========================================================================
  // SEÇÃO DE MISSÕES CUSTOMIZADAS
  // ===========================================================================
  
  /// Constrói a seção de missões customizadas com progresso de bônus.
  Widget _buildCustomMissionsSection() {
    final completedCount = customMissions.where((m) => m.completed).length;
    final totalCount = customMissions.length;
    final allCompleted = completedCount == totalCount && totalCount > 0;
    final reached3Bonus = completedCount >= 3;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: allCompleted 
              ? theme.success 
              : reached3Bonus 
                  ? theme.accent.withOpacity(0.5)
                  : theme.primary.withOpacity(0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: (allCompleted ? theme.success : theme.primary).withOpacity(0.2),
            blurRadius: 12,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.accent.withOpacity(0.2),
                  theme.primary.withOpacity(0.1),
                ],
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(14),
                topRight: Radius.circular(14),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.emoji_events_rounded,
                  color: theme.accent,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Missões Customizadas',
                        style: TextStyle(
                          color: theme.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Foque em sua evolução pessoal',
                        style: TextStyle(
                          color: theme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildProgressBadge(completedCount, totalCount, allCompleted),
              ],
            ),
          ),
          
          // Recompensas
          if (!allCompleted) _buildCustomRewardsInfo(completedCount),
          
          // Lista de missões
          if (customMissions.isEmpty)
            _buildEmptyState('Nenhuma missão customizada hoje')
          else
            ...customMissions.map((mission) => _buildMissionTile(mission)),
          
          // Status de conclusão
          if (allCompleted) _buildCompletionBanner(isFixed: false),
        ],
      ),
    );
  }
  
  // ===========================================================================
  // TILE DE MISSÃO
  // ===========================================================================
  
  /// Constrói o tile individual de uma missão com checkbox e XP.
  Widget _buildMissionTile(MissionModel mission) {
    final isCompleted = mission.completed;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isCompleted 
            ? theme.success.withOpacity(0.1) 
            : theme.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCompleted 
              ? theme.success.withOpacity(0.5)
              : theme.textTertiary.withOpacity(0.2),
          width: 1.5,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isCompleted || isLoading ? null : () => onToggleMission(mission),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Checkbox
                _buildCheckbox(isCompleted),
                
                const SizedBox(width: 16),
                
                // Info da missão
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        mission.name,
                        style: TextStyle(
                          color: isCompleted 
                              ? theme.textSecondary 
                              : theme.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          decoration: isCompleted 
                              ? TextDecoration.lineThrough 
                              : null,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          // Tipo de missão
                          _buildMissionTypeChip(mission),
                          
                          const SizedBox(width: 8),
                          
                          // Categoria (se customizada)
                          if (mission.isCustom && mission.category != null)
                            _buildCategoryChip(mission.category!),
                          
                          const Spacer(),
                          
                          // XP
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: theme.primary.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '+${mission.xp} XP',
                              style: TextStyle(
                                color: theme.primary,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  // ===========================================================================
  // COMPONENTES AUXILIARES
  // ===========================================================================
  
  /// Checkbox visual (não interativo) que indica conclusão da missão.
  Widget _buildCheckbox(bool isCompleted) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: isCompleted ? theme.success : Colors.transparent,
        border: Border.all(
          color: isCompleted ? theme.success : theme.textTertiary,
          width: 2,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: isCompleted
          ? Icon(
              Icons.check_rounded,
              color: Colors.white,
              size: 20,
            )
          : null,
    );
  }
  
  /// Badge circular com contagem de progresso (ex: "3/5").
  Widget _buildProgressBadge(int completed, int total, bool allCompleted) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: allCompleted ? theme.success : theme.primary,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$completed/$total',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
  
  /// Chip indicando tipo da missão (FIXA ou CUSTOM).
  Widget _buildMissionTypeChip(MissionModel mission) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: mission.isFixed 
            ? theme.primary.withOpacity(0.2) 
            : theme.accent.withOpacity(0.2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        mission.isFixed ? 'FIXA' : 'CUSTOM',
        style: TextStyle(
          color: mission.isFixed ? theme.primary : theme.accent,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
  
  /// Chip com ícone e label da categoria da missão customizada.
  Widget _buildCategoryChip(CustomMissionCategory category) {
    IconData icon;
    String label;
    
    switch (category) {
      case CustomMissionCategory.study:
        icon = Icons.book_rounded;
        label = 'ESTUDO';
        break;
      case CustomMissionCategory.fitness:
        icon = Icons.fitness_center_rounded;
        label = 'TREINO';
        break;
      case CustomMissionCategory.habit:
        icon = Icons.star_rounded;
        label = 'HÁBITO';
        break;
      default:
        icon = Icons.category_rounded;
        label = 'OUTRO';
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: theme.accent.withOpacity(0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: theme.accent),
          const SizedBox(width: 2),
          Text(
            label,
            style: TextStyle(
              color: theme.accent,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
  
  /// Info box com recompensas por completar todas as missões fixas.
  Widget _buildFixedRewardsInfo() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.primary.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.card_giftcard_rounded, color: theme.primary, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Complete todas: +2 Disciplina, +1 Hábito, Streak mantido',
              style: TextStyle(
                color: theme.textSecondary,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  /// Info box com próximo bônus de missões customizadas.
  Widget _buildCustomRewardsInfo(int completedCount) {
    final next3 = completedCount < 3;
    final nextAll = completedCount >= 3;
    
    String message;
    if (next3) {
      final remaining = 3 - completedCount;
      message = 'Complete mais $remaining para +1 Hábito';
    } else {
      message = 'Complete todas para +2 Hábito adicional';
    }
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.accent.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.accent.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.emoji_events_rounded, color: theme.accent, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: theme.textSecondary,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  /// Banner verde de parabéns ao completar todas as missões da seção.
  Widget _buildCompletionBanner({required bool isFixed}) {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.success.withOpacity(0.8),
            theme.success.withOpacity(0.6),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            Icons.celebration_rounded,
            color: Colors.white,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isFixed 
                  ? '🔥 Todas as fixas completas! Streak mantido!'
                  : '⭐ Todas customizadas completas! Bônus máximo!',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildEmptyState(String message) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Text(
          message,
          style: TextStyle(
            color: theme.textTertiary,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}
