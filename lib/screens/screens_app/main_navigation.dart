import 'package:flutter/material.dart';
import 'package:monarch/core/theme/rank_themes.dart';
import 'package:monarch/providers/user_provider.dart';
import 'package:monarch/screens/screens_app/home_screen.dart';
import 'package:monarch/screens/screens_app/missions_screen.dart';
import 'package:monarch/screens/screens_app/ranking_screen.dart';
import 'package:monarch/screens/screens_app/attributes_screen.dart';
import 'package:provider/provider.dart';

/// Tela principal com navegação por tabs
class MainNavigation extends StatefulWidget {
  const MainNavigation({Key? key}) : super(key: key);

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;

  // Cache das telas para evitar reconstruções
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = const [
      HomeScreen(),
      MissionsScreen(),
      RankingScreen(),
      AttributesScreen(),
    ];
  }

  final List<_NavItem> _navItems = const [
    _NavItem(
      icon: Icons.home_outlined,
      activeIcon: Icons.home,
      label: 'Início',
    ),
    _NavItem(
      icon: Icons.assignment_outlined,
      activeIcon: Icons.assignment,
      label: 'Missões',
    ),
    _NavItem(
      icon: Icons.leaderboard_outlined,
      activeIcon: Icons.leaderboard,
      label: 'Ranking',
    ),
    _NavItem(
      icon: Icons.military_tech_outlined,
      activeIcon: Icons.military_tech,
      label: 'Atributos',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    // Usa Selector para ouvir apenas mudanças no rank
    return Selector<UserProvider, String>(
      selector: (_, userProvider) => userProvider.currentUser?.rank ?? 'E',
      builder: (context, rank, _) {
        final theme = _getThemeForRank(rank);

        return Scaffold(
          body: IndexedStack(
            index: _currentIndex,
            children: _screens,
          ),
          bottomNavigationBar: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.surface,
                  theme.background,
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: List.generate(
                    _navItems.length,
                    (index) => _buildNavItem(
                      _navItems[index],
                      index,
                      theme,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildNavItem(_NavItem item, int index, RankTheme theme) {
    final isActive = _currentIndex == index;

    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _currentIndex = index),
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            gradient: isActive
                ? LinearGradient(
                    colors: [
                      theme.primary.withOpacity(0.2),
                      theme.accent.withOpacity(0.1),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            borderRadius: BorderRadius.circular(12),
            border: isActive
                ? Border.all(
                    color: theme.primary.withOpacity(0.5),
                    width: 1,
                  )
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isActive ? item.activeIcon : item.icon,
                color: isActive ? theme.primary : theme.textSecondary,
                size: 26,
              ),
              const SizedBox(height: 4),
              Text(
                item.label,
                style: TextStyle(
                  color: isActive ? theme.primary : theme.textSecondary,
                  fontSize: 11,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                  letterSpacing: 0.5,
                ),
              ),
              if (isActive) ...[
                const SizedBox(height: 4),
                Container(
                  width: 20,
                  height: 3,
                  decoration: BoxDecoration(
                    gradient: theme.primaryGradient,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  RankTheme _getThemeForRank(String rank) {
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
}

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}
