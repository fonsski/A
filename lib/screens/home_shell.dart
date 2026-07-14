import 'package:flutter/material.dart';

import '../widgets/common.dart';
import 'chats_screen.dart';
import 'profile_screen.dart';
import 'settings_screen.dart';
import 'wall_screen.dart';

/// Четыре вкладки нижней навигации: чаты, стенка, настройки, профиль.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  void _select(int i) => setState(() => _index = i);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: IndexedStack(
          index: _index,
          children: [
            const ChatsScreen(),
            const WallScreen(),
            const SettingsScreen(),
            ProfileScreen(onOpenWall: () => _select(1)),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: ABottomNav(index: _index, onTap: _select),
      ),
    );
  }
}
