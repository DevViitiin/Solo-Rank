import 'package:flutter/material.dart';
import 'package:monarch/core/theme/rank_themes.dart';
import 'package:monarch/providers/user_provider.dart';
import 'package:monarch/screens/app/attributes_screen.dart';
import 'package:monarch/screens/app/home_screen.dart';
import 'package:monarch/screens/app/missions_screen.dart';
import 'package:monarch/screens/app/ranking_screen.dart';
import 'package:monarch/screens/auth/onboarding_guide.dart';
import 'package:provider/provider.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({Key? key}) : super(key: key);

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;

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

  @override
  Widget build(BuildContext context) {
    return Selector<UserProvider, _NavState>(
      selector: (_, p) => _NavState(
        rank: p.currentUser?.rank ?? 'E',
        // Quando onboardingCompleted for true no Firebase, o UserProvider
        // atualiza currentUser e o Selector reconstrói removendo o overlay.
        onboardingCompleted: p.currentUser?.onboardingCompleted ?? false,
      ),
      builder: (context, state, _) {
        final theme = _getThemeForRank(state.rank);

        final scaffold = Scaffold(
          body: IndexedStack(index: _currentIndex, children: _screens),
          bottomNavigationBar: _buildNavBar(theme),
        );

        // Overlay some automaticamente quando UserProvider recebe
        // onboardingCompleted: true do Firebase (via loadUser ou stream).
        if (state.onboardingCompleted) return scaffold;

        return Stack(
          children: [
            scaffold,
            Positioned.fill(child: const OnboardingGuide()),
          ],
        );
      },
    );
  }

  Widget _buildNavBar(RankTheme theme) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [theme.surface, theme.background],
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
              (i) => _buildNavItem(_navItems[i], i, theme),
            ),
          ),
        ),
      ),
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
                ? Border.all(color: theme.primary.withOpacity(0.5), width: 1)
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
      case 'E':   return RankThemes.e;
      case 'D':   return RankThemes.d;
      case 'C':   return RankThemes.c;
      case 'B':   return RankThemes.b;
      case 'A':   return RankThemes.a;
      case 'S':   return RankThemes.s;
      case 'SS':  return RankThemes.ss;
      case 'SSS': return RankThemes.sss;
      default:    return RankThemes.e;
    }
  }
}

// =============================================================================
// HELPERS
// =============================================================================

const List<_NavItem> _navItems = [
  _NavItem(icon: Icons.home_outlined,          activeIcon: Icons.home,          label: 'Início'),
  _NavItem(icon: Icons.assignment_outlined,    activeIcon: Icons.assignment,    label: 'Missões'),
  _NavItem(icon: Icons.leaderboard_outlined,   activeIcon: Icons.leaderboard,   label: 'Ranking'),
  _NavItem(icon: Icons.military_tech_outlined, activeIcon: Icons.military_tech, label: 'Atributos'),
];

class _NavState {
  final String rank;
  final bool onboardingCompleted;

  const _NavState({required this.rank, required this.onboardingCompleted});

  @override
  bool operator ==(Object other) =>
      other is _NavState &&
      other.rank == rank &&
      other.onboardingCompleted == onboardingCompleted;

  @override
  int get hashCode => Object.hash(rank, onboardingCompleted);
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
