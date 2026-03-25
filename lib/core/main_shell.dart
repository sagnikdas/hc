import 'package:flutter/material.dart';
import '../features/home/home_screen.dart';
import '../features/progress/progress_screen.dart';
import '../features/leaderboard/leaderboard_screen.dart';
import '../features/profile/profile_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    const screens = [
      HomeScreen(),
      ProgressScreen(),
      LeaderboardScreen(),
      ProfileScreen(),
    ];
    return Scaffold(
      backgroundColor: cs.surface,
      body: IndexedStack(index: _currentIndex, children: screens),
      bottomNavigationBar: _SacredNavBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
      ),
    );
  }
}

class _SacredNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  const _SacredNavBar({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bottom = MediaQuery.of(context).padding.bottom;
    const icons = [
      Icons.home_rounded,
      Icons.history_rounded,
      Icons.emoji_events_rounded,
      Icons.settings_rounded,
    ];
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1C1B1B).withValues(alpha: 0.95),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.04),
            blurRadius: 24,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(16, 14, 16, 14 + bottom),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(4, (i) {
          final isSelected = i == currentIndex;
          return GestureDetector(
            onTap: () => onTap(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isSelected ? cs.primary : Colors.transparent,
                shape: BoxShape.circle,
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                            color: cs.primary.withValues(alpha: 0.4),
                            blurRadius: 15)
                      ]
                    : null,
              ),
              child: Icon(
                icons[i],
                color: isSelected
                    ? const Color(0xFF131313)
                    : cs.primary.withValues(alpha: 0.5),
                size: 22,
              ),
            ),
          );
        }),
      ),
    );
  }
}
