import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';

/// Serviço centralizado de notificações popup do sistema Dracoryx.
///
/// Gerencia todos os tipos de popups (conquistas, level ups, streaks,
/// rank ups, avisos, dicas e recompensas) com:
/// - **Persistência em Hive**: histórico para controle de frequência
/// - **Fila de prioridade**: popups são ordenados por [PopupPriority]
/// - **Controle de exibição**: popups mostrados apenas 1x por dia (configurável)
/// - **Limpeza automática**: histórico >30 dias é removido
///
/// Implementado como Singleton via [PopupService.instance].
class PopupService {
  static final PopupService _instance = PopupService._();
  static PopupService get instance => _instance;
  
  PopupService._();
  
  late Box _popupsBox;
  bool _initialized = false;
  
  // Fila de popups pendentes
  final List<_PopupQueueItem> _queue = [];
  bool _isShowingPopup = false;
  
  // =========================================================================
  // TIPOS DE POPUPS
  // =========================================================================
  
  /// Conquistas
  static const String TYPE_ACHIEVEMENT = 'achievement';
  
  /// Level up
  static const String TYPE_LEVEL_UP = 'level_up';
  
  /// Rank up
  static const String TYPE_RANK_UP = 'rank_up';
  
  /// Streak milestone
  static const String TYPE_STREAK = 'streak';
  
  /// Atributo subiu
  static const String TYPE_ATTRIBUTE = 'attribute';
  
  /// Aviso geral
  static const String TYPE_WARNING = 'warning';
  
  /// Informação
  static const String TYPE_INFO = 'info';
  
  /// Sucesso
  static const String TYPE_SUCCESS = 'success';
  
  /// Erro
  static const String TYPE_ERROR = 'error';
  
  /// Recompensa
  static const String TYPE_REWARD = 'reward';
  
  /// Tutorial/Dica
  static const String TYPE_TIP = 'tip';
  
  // =========================================================================
  // CONQUISTAS ESPECÍFICAS - ✅ ATUALIZADO
  // =========================================================================
  
  static const String ACHIEVEMENT_ALL_FIXED = 'all_fixed_missions_completed';
  static const String ACHIEVEMENT_3_CUSTOM = '3_custom_missions_completed';
  static const String ACHIEVEMENT_ALL_CUSTOM = 'all_custom_missions_completed';
  static const String ACHIEVEMENT_PERFECT_DAY = 'perfect_day_completed';
  static const String ACHIEVEMENT_FIRST_MISSION = 'first_mission_completed';
  static const String ACHIEVEMENT_WEEK_STREAK = 'week_streak_completed';
  static const String ACHIEVEMENT_MONTH_STREAK = 'month_streak_completed';
  
  // =========================================================================
  // INICIALIZAÇÃO
  // =========================================================================
  
  /// Inicializa o Hive box de histórico e limpa entradas antigas.
  ///
  /// Seguro para chamar múltiplas vezes (idempotente).
  Future<void> init() async {
    if (_initialized) return;
    
    try {
      _popupsBox = await Hive.openBox('popups_history');
      _initialized = true;
      
      debugPrint('✅ PopupService inicializado');
      debugPrint('   Histórico: ${_popupsBox.length} popups');
      
      // Limpar histórico antigo
      await _cleanOldHistory();
      
    } catch (e) {
      debugPrint('❌ Erro ao inicializar PopupService: $e');
      rethrow;
    }
  }
  
  // =========================================================================
  // VERIFICAÇÃO DE POPUPS
  // =========================================================================
  
  /// Verifica se um popup já foi mostrado hoje
  Future<bool> wasShownToday(String userId, String popupId) async {
    if (!_initialized) await init();
    
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final key = '${userId}_${popupId}_$today';
    
    return _popupsBox.get(key, defaultValue: false) as bool;
  }
  
  /// Verifica se um popup já foi mostrado (qualquer dia)
  Future<bool> wasEverShown(String userId, String popupId) async {
    if (!_initialized) await init();
    
    final prefix = '${userId}_${popupId}_';
    
    for (final key in _popupsBox.keys) {
      if (key is String && key.startsWith(prefix)) {
        return true;
      }
    }
    
    return false;
  }
  
  /// Conta quantas vezes um popup foi mostrado
  Future<int> getShowCount(String userId, String popupId) async {
    if (!_initialized) await init();
    
    final prefix = '${userId}_${popupId}_';
    int count = 0;
    
    for (final key in _popupsBox.keys) {
      if (key is String && key.startsWith(prefix)) {
        count++;
      }
    }
    
    return count;
  }
  
  /// Marca um popup como mostrado
  Future<void> _markAsShown(String userId, String popupId) async {
    if (!_initialized) await init();
    
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final key = '${userId}_${popupId}_$today';
    
    await _popupsBox.put(key, true);
    
    debugPrint('✅ Popup marcado como mostrado: $popupId');
  }
  
  // =========================================================================
  // VERIFICAÇÕES ESPECÍFICAS DE CONQUISTAS - ✅ ATUALIZADO
  // =========================================================================
  
  /// Verifica se pode mostrar popup de todas as missões fixas (3, 4 ou 5)
  Future<bool> canShowAllFixedPopup(String userId) async {
    return !(await wasShownToday(userId, ACHIEVEMENT_ALL_FIXED));
  }
  
  /// Verifica se pode mostrar popup de 3 missões customizadas
  Future<bool> canShow3CustomPopup(String userId) async {
    return !(await wasShownToday(userId, ACHIEVEMENT_3_CUSTOM));
  }
  
  /// Verifica se pode mostrar popup de todas as missões customizadas (7)
  Future<bool> canShowAllCustomPopup(String userId) async {
    return !(await wasShownToday(userId, ACHIEVEMENT_ALL_CUSTOM));
  }
  
  /// Verifica se pode mostrar popup de dia perfeito
  Future<bool> canShowPerfectDayPopup(String userId) async {
    return !(await wasShownToday(userId, ACHIEVEMENT_PERFECT_DAY));
  }
  
  /// Marca popup de todas fixas como mostrado
  Future<void> markAllFixedShown(String userId) async {
    await _markAsShown(userId, ACHIEVEMENT_ALL_FIXED);
  }
  
  /// Marca popup de 3 customizadas como mostrado
  Future<void> mark3CustomShown(String userId) async {
    await _markAsShown(userId, ACHIEVEMENT_3_CUSTOM);
  }
  
  /// Marca popup de todas customizadas como mostrado
  Future<void> markAllCustomShown(String userId) async {
    await _markAsShown(userId, ACHIEVEMENT_ALL_CUSTOM);
  }
  
  /// Marca popup de dia perfeito como mostrado
  Future<void> markPerfectDayShown(String userId) async {
    await _markAsShown(userId, ACHIEVEMENT_PERFECT_DAY);
  }
  
  // =========================================================================
  // EXIBIÇÃO DE POPUPS - CONQUISTAS - ✅ ATUALIZADO
  // =========================================================================
  
  /// Mostra popup de conquista de todas as missões fixas (variável: 3, 4 ou 5)
  Future<bool> showAllFixedMissionsPopup(
    BuildContext context,
    String userId,
    int totalFixed, {
    VoidCallback? onClose,
  }) async {
    if (await wasShownToday(userId, ACHIEVEMENT_ALL_FIXED)) {
      debugPrint('⏭️ Popup todas fixas já foi mostrado hoje');
      return false;
    }
    
    // Bônus varia conforme total
    final bonus = totalFixed == 5 ? 50 : (totalFixed == 4 ? 40 : 30);
    
    return await _showPopup(
      context: context,
      userId: userId,
      popupId: ACHIEVEMENT_ALL_FIXED,
      type: TYPE_ACHIEVEMENT,
      title: '🎯 Mestre das Fixas!',
      message: 'Você completou todas as $totalFixed missões fixas hoje!\n\n+$bonus XP de bônus',
      primaryButton: 'Continuar',
      onClose: onClose,
    );
  }
  
  /// Mostra popup de conquista de 3 missões customizadas
  Future<bool> show3CustomMissionsPopup(
    BuildContext context,
    String userId, {
    VoidCallback? onClose,
  }) async {
    if (await wasShownToday(userId, ACHIEVEMENT_3_CUSTOM)) {
      debugPrint('⏭️ Popup 3 custom já foi mostrado hoje');
      return false;
    }
    
    return await _showPopup(
      context: context,
      userId: userId,
      popupId: ACHIEVEMENT_3_CUSTOM,
      type: TYPE_ACHIEVEMENT,
      title: '🔥 Começou Bem!',
      message: '3 missões customizadas completadas!\n\n+30 XP de bônus',
      primaryButton: 'Continuar',
      onClose: onClose,
    );
  }
  
  /// Mostra popup de conquista de todas as missões customizadas (7)
  Future<bool> showAllCustomMissionsPopup(
    BuildContext context,
    String userId, {
    VoidCallback? onClose,
  }) async {
    if (await wasShownToday(userId, ACHIEVEMENT_ALL_CUSTOM)) {
      debugPrint('⏭️ Popup todas custom já foi mostrado hoje');
      return false;
    }
    
    return await _showPopup(
      context: context,
      userId: userId,
      popupId: ACHIEVEMENT_ALL_CUSTOM,
      type: TYPE_ACHIEVEMENT,
      title: '🏆 Produtividade Máxima!',
      message: 'Incrível! Todas as 7 missões customizadas completadas!\n\n+70 XP de bônus',
      primaryButton: 'Continuar',
      onClose: onClose,
    );
  }
  
  /// Mostra popup de dia perfeito
  Future<bool> showPerfectDayPopup(
    BuildContext context,
    String userId, {
    VoidCallback? onClose,
  }) async {
    if (await wasShownToday(userId, ACHIEVEMENT_PERFECT_DAY)) {
      debugPrint('⏭️ Popup dia perfeito já foi mostrado hoje');
      return false;
    }
    
    return await _showPopup(
      context: context,
      userId: userId,
      popupId: ACHIEVEMENT_PERFECT_DAY,
      type: TYPE_ACHIEVEMENT,
      title: '⭐ Dia Perfeito!',
      message: 'Você completou TODAS as missões de hoje!\n\nFixas + Customizadas = Perfeição!\n\n+150 XP de bônus',
      primaryButton: 'Incrível!',
      onClose: onClose,
    );
  }
  
  // =========================================================================
  // EXIBIÇÃO DE POPUPS - PROGRESSÃO
  // =========================================================================
  
  /// Mostra popup de level up
  Future<bool> showLevelUpPopup(
    BuildContext context,
    String userId,
    int newLevel, {
    int? xpGained,
    VoidCallback? onClose,
  }) async {
    final popupId = 'level_up_$newLevel';
    
    return await _showPopup(
      context: context,
      userId: userId,
      popupId: popupId,
      type: TYPE_LEVEL_UP,
      title: '🎉 Level Up!',
      message: 'Parabéns! Você alcançou o Level $newLevel${xpGained != null ? '\n\n+$xpGained XP' : ''}',
      primaryButton: 'Continuar',
      priority: PopupPriority.high,
      onClose: onClose,
    );
  }
  
  /// Mostra popup de rank up
  Future<bool> showRankUpPopup(
    BuildContext context,
    String userId,
    String newRank,
    String oldRank, {
    VoidCallback? onClose,
  }) async {
    final popupId = 'rank_up_$newRank';
    
    return await _showPopup(
      context: context,
      userId: userId,
      popupId: popupId,
      type: TYPE_RANK_UP,
      title: '📊 Rank Up!',
      message: 'Você subiu de rank!\n\n$oldRank → $newRank',
      primaryButton: 'Continuar',
      priority: PopupPriority.high,
      onClose: onClose,
    );
  }
  
  /// Mostra popup de streak milestone
  Future<bool> showStreakMilestonePopup(
    BuildContext context,
    String userId,
    int streakDays, {
    VoidCallback? onClose,
  }) async {
    final popupId = 'streak_milestone_$streakDays';
    
    String emoji = '🔥';
    String title = 'Streak de $streakDays dias!';
    String message = 'Continue assim!';
    
    if (streakDays >= 30) {
      emoji = '🏆';
      title = 'Lendário!';
      message = '$streakDays dias de streak!\nVocê é uma máquina!';
    } else if (streakDays >= 14) {
      emoji = '⚡';
      title = 'Imparável!';
      message = '$streakDays dias consecutivos!\nIncredível!';
    } else if (streakDays >= 7) {
      emoji = '🔥';
      title = 'Uma semana!';
      message = '$streakDays dias de dedicação!';
    }
    
    return await _showPopup(
      context: context,
      userId: userId,
      popupId: popupId,
      type: TYPE_STREAK,
      title: '$emoji $title',
      message: message,
      primaryButton: 'Continuar',
      priority: PopupPriority.medium,
      onClose: onClose,
    );
  }
  
  /// Mostra popup de atributo subindo
  Future<bool> showAttributeUpPopup(
    BuildContext context,
    String userId,
    String attributeName,
    int newValue, {
    VoidCallback? onClose,
  }) async {
    final popupId = 'attribute_${attributeName}_$newValue';
    
    final emoji = _getAttributeEmoji(attributeName);
    
    return await _showPopup(
      context: context,
      userId: userId,
      popupId: popupId,
      type: TYPE_ATTRIBUTE,
      title: '$emoji $attributeName +1',
      message: 'Seu atributo de $attributeName aumentou!\n\nNovo valor: $newValue',
      primaryButton: 'Continuar',
      priority: PopupPriority.low,
      onClose: onClose,
    );
  }
  
  // =========================================================================
  // EXIBIÇÃO DE POPUPS - GENÉRICOS
  // =========================================================================
  
  /// Mostra popup de sucesso
  Future<bool> showSuccess(
    BuildContext context,
    String userId, {
    required String title,
    required String message,
    String? primaryButton,
    VoidCallback? onPrimaryPressed,
    VoidCallback? onClose,
  }) async {
    return await _showPopup(
      context: context,
      userId: userId,
      popupId: 'success_${DateTime.now().millisecondsSinceEpoch}',
      type: TYPE_SUCCESS,
      title: title,
      message: message,
      primaryButton: primaryButton ?? 'OK',
      onPrimaryPressed: onPrimaryPressed,
      onClose: onClose,
      showOnlyOnce: false, // Sempre mostrar
    );
  }
  
  /// Mostra popup de erro
  Future<bool> showError(
    BuildContext context,
    String userId, {
    required String title,
    required String message,
    String? primaryButton,
    VoidCallback? onPrimaryPressed,
    VoidCallback? onClose,
  }) async {
    return await _showPopup(
      context: context,
      userId: userId,
      popupId: 'error_${DateTime.now().millisecondsSinceEpoch}',
      type: TYPE_ERROR,
      title: title,
      message: message,
      primaryButton: primaryButton ?? 'OK',
      onPrimaryPressed: onPrimaryPressed,
      onClose: onClose,
      showOnlyOnce: false,
    );
  }
  
  /// Mostra popup de aviso
  Future<bool> showWarning(
    BuildContext context,
    String userId, {
    required String title,
    required String message,
    String? primaryButton,
    String? secondaryButton,
    VoidCallback? onPrimaryPressed,
    VoidCallback? onSecondaryPressed,
    VoidCallback? onClose,
  }) async {
    return await _showPopup(
      context: context,
      userId: userId,
      popupId: 'warning_${DateTime.now().millisecondsSinceEpoch}',
      type: TYPE_WARNING,
      title: title,
      message: message,
      primaryButton: primaryButton ?? 'OK',
      secondaryButton: secondaryButton,
      onPrimaryPressed: onPrimaryPressed,
      onSecondaryPressed: onSecondaryPressed,
      onClose: onClose,
      showOnlyOnce: false,
    );
  }
  
  /// Mostra popup de informação
  Future<bool> showInfo(
    BuildContext context,
    String userId, {
    required String title,
    required String message,
    String? primaryButton,
    VoidCallback? onPrimaryPressed,
    VoidCallback? onClose,
  }) async {
    return await _showPopup(
      context: context,
      userId: userId,
      popupId: 'info_${DateTime.now().millisecondsSinceEpoch}',
      type: TYPE_INFO,
      title: title,
      message: message,
      primaryButton: primaryButton ?? 'OK',
      onPrimaryPressed: onPrimaryPressed,
      onClose: onClose,
      showOnlyOnce: false,
    );
  }
  
  /// Mostra popup de dica/tutorial
  Future<bool> showTip(
    BuildContext context,
    String userId, {
    required String tipId,
    required String title,
    required String message,
    String? primaryButton,
    VoidCallback? onClose,
  }) async {
    // Dicas são mostradas apenas uma vez
    if (await wasEverShown(userId, 'tip_$tipId')) {
      debugPrint('⏭️ Dica $tipId já foi mostrada anteriormente');
      return false;
    }
    
    return await _showPopup(
      context: context,
      userId: userId,
      popupId: 'tip_$tipId',
      type: TYPE_TIP,
      title: title,
      message: message,
      primaryButton: primaryButton ?? 'Entendi',
      onClose: onClose,
      showOnlyOnce: true,
    );
  }
  
  // =========================================================================
  // SISTEMA DE FILA
  // =========================================================================
  
  /// Adiciona popup na fila ordenada por prioridade (maior primeiro).
  void _addToQueue(_PopupQueueItem item) {
    _queue.add(item);
    _queue.sort((a, b) => b.priority.index.compareTo(a.priority.index));
    
    debugPrint('📋 Popup adicionado à fila: ${item.popupId}');
    debugPrint('   Prioridade: ${item.priority.name}');
    debugPrint('   Fila atual: ${_queue.length} popups');
  }
  
  /// Processa sequencialmente todos os popups da fila.
  ///
  /// Aguarda 300ms entre cada popup para transição suave.
  /// Reentrant-safe via flag [_isShowingPopup].
  Future<void> _processQueue(BuildContext context) async {
    if (_isShowingPopup || _queue.isEmpty) return;
    
    _isShowingPopup = true;
    
    while (_queue.isNotEmpty) {
      final item = _queue.removeAt(0);
      
      debugPrint('📤 Processando popup da fila: ${item.popupId}');
      
      await _showPopupDialog(
        context: context,
        item: item,
      );
      
      // Aguardar um pouco entre popups
      await Future.delayed(const Duration(milliseconds: 300));
    }
    
    _isShowingPopup = false;
  }
  
  // =========================================================================
  // EXIBIÇÃO INTERNA
  // =========================================================================
  
  /// Método interno para enfileirar e exibir um popup.
  ///
  /// Verifica duplicidade via [wasShownToday] quando [showOnlyOnce] é `true`.
  /// Retorna `true` se o popup foi enfileirado, `false` se já foi mostrado.
  Future<bool> _showPopup({
    required BuildContext context,
    required String userId,
    required String popupId,
    required String type,
    required String title,
    required String message,
    String? primaryButton,
    String? secondaryButton,
    VoidCallback? onPrimaryPressed,
    VoidCallback? onSecondaryPressed,
    VoidCallback? onClose,
    PopupPriority priority = PopupPriority.medium,
    bool showOnlyOnce = true,
  }) async {
    if (!_initialized) await init();
    
    // Verificar se já foi mostrado (se showOnlyOnce = true)
    if (showOnlyOnce && await wasShownToday(userId, popupId)) {
      debugPrint('⏭️ Popup $popupId já foi mostrado hoje');
      return false;
    }
    
    final item = _PopupQueueItem(
      userId: userId,
      popupId: popupId,
      type: type,
      title: title,
      message: message,
      primaryButton: primaryButton ?? 'OK',
      secondaryButton: secondaryButton,
      onPrimaryPressed: onPrimaryPressed,
      onSecondaryPressed: onSecondaryPressed,
      onClose: onClose,
      priority: priority,
      showOnlyOnce: showOnlyOnce,
    );
    
    _addToQueue(item);
    _processQueue(context);
    
    return true;
  }
  
  /// Renderiza o dialog Material do popup com cores baseadas no tipo.
  Future<void> _showPopupDialog({
    required BuildContext context,
    required _PopupQueueItem item,
  }) async {
    final colors = _getPopupColors(item.type);
    
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  colors.background,
                  colors.background.withOpacity(0.8),
                ],
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Ícone
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colors.iconBackground,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    colors.icon,
                    size: 48,
                    color: colors.iconColor,
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Título
                Text(
                  item.title,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 12),
                
                // Mensagem
                Text(
                  item.message,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 24),
                
                // Botões
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Botão secundário
                    if (item.secondaryButton != null) ...[
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                            item.onSecondaryPressed?.call();
                            item.onClose?.call();
                          },
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(item.secondaryButton!),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    
                    // Botão primário
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          item.onPrimaryPressed?.call();
                          item.onClose?.call();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colors.buttonColor,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          item.primaryButton,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    
    // Marcar como mostrado
    if (item.showOnlyOnce) {
      await _markAsShown(item.userId, item.popupId);
    }
  }
  
  // =========================================================================
  // HELPERS
  // =========================================================================
  
  /// Mapeia o tipo de popup para seu esquema de cores (fundo, ícone, botão).
  _PopupColors _getPopupColors(String type) {
    switch (type) {
      case TYPE_ACHIEVEMENT:
        return _PopupColors(
          background: Colors.amber[50]!,
          iconBackground: Colors.amber[100]!,
          icon: Icons.emoji_events,
          iconColor: Colors.amber[700]!,
          buttonColor: Colors.amber[600]!,
        );
        
      case TYPE_LEVEL_UP:
        return _PopupColors(
          background: Colors.purple[50]!,
          iconBackground: Colors.purple[100]!,
          icon: Icons.stars,
          iconColor: Colors.purple[700]!,
          buttonColor: Colors.purple[600]!,
        );
        
      case TYPE_RANK_UP:
        return _PopupColors(
          background: Colors.blue[50]!,
          iconBackground: Colors.blue[100]!,
          icon: Icons.trending_up,
          iconColor: Colors.blue[700]!,
          buttonColor: Colors.blue[600]!,
        );
        
      case TYPE_STREAK:
        return _PopupColors(
          background: Colors.orange[50]!,
          iconBackground: Colors.orange[100]!,
          icon: Icons.local_fire_department,
          iconColor: Colors.orange[700]!,
          buttonColor: Colors.orange[600]!,
        );
        
      case TYPE_ATTRIBUTE:
        return _PopupColors(
          background: Colors.green[50]!,
          iconBackground: Colors.green[100]!,
          icon: Icons.arrow_upward,
          iconColor: Colors.green[700]!,
          buttonColor: Colors.green[600]!,
        );
        
      case TYPE_SUCCESS:
        return _PopupColors(
          background: Colors.green[50]!,
          iconBackground: Colors.green[100]!,
          icon: Icons.check_circle,
          iconColor: Colors.green[700]!,
          buttonColor: Colors.green[600]!,
        );
        
      case TYPE_ERROR:
        return _PopupColors(
          background: Colors.red[50]!,
          iconBackground: Colors.red[100]!,
          icon: Icons.error,
          iconColor: Colors.red[700]!,
          buttonColor: Colors.red[600]!,
        );
        
      case TYPE_WARNING:
        return _PopupColors(
          background: Colors.orange[50]!,
          iconBackground: Colors.orange[100]!,
          icon: Icons.warning,
          iconColor: Colors.orange[700]!,
          buttonColor: Colors.orange[600]!,
        );
        
      case TYPE_INFO:
        return _PopupColors(
          background: Colors.blue[50]!,
          iconBackground: Colors.blue[100]!,
          icon: Icons.info,
          iconColor: Colors.blue[700]!,
          buttonColor: Colors.blue[600]!,
        );
        
      case TYPE_TIP:
        return _PopupColors(
          background: Colors.teal[50]!,
          iconBackground: Colors.teal[100]!,
          icon: Icons.lightbulb,
          iconColor: Colors.teal[700]!,
          buttonColor: Colors.teal[600]!,
        );
        
      case TYPE_REWARD:
        return _PopupColors(
          background: Colors.pink[50]!,
          iconBackground: Colors.pink[100]!,
          icon: Icons.card_giftcard,
          iconColor: Colors.pink[700]!,
          buttonColor: Colors.pink[600]!,
        );
        
      default:
        return _PopupColors(
          background: Colors.grey[50]!,
          iconBackground: Colors.grey[100]!,
          icon: Icons.notifications,
          iconColor: Colors.grey[700]!,
          buttonColor: Colors.grey[600]!,
        );
    }
  }
  
  /// Retorna emoji para atributo
  String _getAttributeEmoji(String attributeName) {
    switch (attributeName.toLowerCase()) {
      case 'study':
      case 'estudo':
        return '📚';
      case 'discipline':
      case 'disciplina':
        return '💪';
      case 'evolution':
      case 'evolução':
      case 'evolucao':
        return '🚀';
      case 'shape':
        return '🏃';
      case 'habit':
      case 'hábito':
      case 'habito':
        return '⭐';
      default:
        return '📊';
    }
  }
  
  // =========================================================================
  // LIMPEZA
  // =========================================================================
  
  /// Remove entradas do histórico com mais de 30 dias.
  ///
  /// Extrai a data da chave (formato: `userId_popupId_yyyy-MM-dd`)
  /// e remove as que ultrapassaram o prazo.
  Future<void> _cleanOldHistory() async {
    try {
      final now = DateTime.now();
      final keysToDelete = <String>[];
      
      for (final key in _popupsBox.keys) {
        if (key is! String) continue;
        
        // Extrair data da chave (formato: userId_popupId_yyyy-MM-dd)
        final parts = key.split('_');
        if (parts.length < 3) continue;
        
        final dateStr = parts.last;
        try {
          final date = DateTime.parse(dateStr);
          final age = now.difference(date).inDays;
          
          if (age > 30) {
            keysToDelete.add(key);
          }
        } catch (e) {
          // Data inválida, ignorar
          continue;
        }
      }
      
      for (final key in keysToDelete) {
        await _popupsBox.delete(key);
      }
      
      if (keysToDelete.isNotEmpty) {
        debugPrint('🗑️ Limpeza: ${keysToDelete.length} popups antigos removidos');
      }
    } catch (e) {
      debugPrint('❌ Erro ao limpar histórico: $e');
    }
  }
  
  /// Limpa todo o histórico de popups (uso em debug).
  Future<void> resetAll() async {
    if (!_initialized) await init();
    
    await _popupsBox.clear();
    debugPrint('🗑️ Todo histórico de popups resetado');
  }
  
  /// Reseta popups de um usuário específico
  Future<void> resetUser(String userId) async {
    if (!_initialized) await init();
    
    final keysToDelete = <String>[];
    
    for (final key in _popupsBox.keys) {
      if (key is String && key.startsWith(userId)) {
        keysToDelete.add(key);
      }
    }
    
    for (final key in keysToDelete) {
      await _popupsBox.delete(key);
    }
    
    debugPrint('🗑️ Histórico do usuário $userId resetado (${keysToDelete.length} popups)');
  }
  
  // =========================================================================
  // DEBUG
  // =========================================================================
  
  /// Imprime histórico formatado de popups no console de debug.
  ///
  /// Se [userId] fornecido, filtra apenas popups desse usuário.
  void printHistory([String? userId]) {
    if (!_initialized) {
      debugPrint('⚠️ PopupService não inicializado');
      return;
    }
    
    debugPrint('┌────────────────────────────────────────────');
    debugPrint('│ 📋 HISTÓRICO DE POPUPS');
    debugPrint('├────────────────────────────────────────────');
    
    if (_popupsBox.isEmpty) {
      debugPrint('│   (vazio)');
    } else {
      int count = 0;
      
      for (final key in _popupsBox.keys) {
        if (key is! String) continue;
        
        if (userId != null && !key.startsWith(userId)) continue;
        
        final value = _popupsBox.get(key);
        debugPrint('│   $key: $value');
        count++;
      }
      
      if (userId != null && count == 0) {
        debugPrint('│   (nenhum popup para usuário $userId)');
      }
    }
    
    debugPrint('├────────────────────────────────────────────');
    debugPrint('│ Total: ${_popupsBox.length} popups');
    debugPrint('│ Fila: ${_queue.length} pendentes');
    debugPrint('└────────────────────────────────────────────');
  }
  
  /// Retorna estatísticas agregadas dos popups (total por tipo, fila, etc.).
  Map<String, dynamic> getStats([String? userId]) {
    if (!_initialized) return {};
    
    int total = 0;
    final byType = <String, int>{};
    
    for (final key in _popupsBox.keys) {
      if (key is! String) continue;
      if (userId != null && !key.startsWith(userId)) continue;
      
      total++;
      
      // Tentar extrair tipo do popupId
      final parts = key.split('_');
      if (parts.length >= 2) {
        final type = parts[1];
        byType[type] = (byType[type] ?? 0) + 1;
      }
    }
    
    return {
      'total': total,
      'by_type': byType,
      'queue_size': _queue.length,
      'is_showing': _isShowingPopup,
    };
  }
}

// =============================================================================
// CLASSES AUXILIARES
// =============================================================================

/// Níveis de prioridade para ordenação na fila de popups.
///
/// Popups de maior prioridade são exibidos primeiro.
enum PopupPriority {
  low,
  medium,
  high,
  critical,
}

/// Representação interna de um popup na fila de exibição.
///
/// Contém todos os dados necessários para renderizar o dialog:
/// título, mensagem, botões, callbacks e configurações de controle.
class _PopupQueueItem {
  final String userId;
  final String popupId;
  final String type;
  final String title;
  final String message;
  final String primaryButton;
  final String? secondaryButton;
  final VoidCallback? onPrimaryPressed;
  final VoidCallback? onSecondaryPressed;
  final VoidCallback? onClose;
  final PopupPriority priority;
  final bool showOnlyOnce;
  
  _PopupQueueItem({
    required this.userId,
    required this.popupId,
    required this.type,
    required this.title,
    required this.message,
    required this.primaryButton,
    this.secondaryButton,
    this.onPrimaryPressed,
    this.onSecondaryPressed,
    this.onClose,
    this.priority = PopupPriority.medium,
    this.showOnlyOnce = true,
  });
}

/// Esquema de cores para renderização de um popup.
///
/// Define fundo, ícone e cor do botão primário baseado no tipo.
class _PopupColors {
  final Color background;
  final Color iconBackground;
  final IconData icon;
  final Color iconColor;
  final Color buttonColor;
  
  _PopupColors({
    required this.background,
    required this.iconBackground,
    required this.icon,
    required this.iconColor,
    required this.buttonColor,
  });
}
