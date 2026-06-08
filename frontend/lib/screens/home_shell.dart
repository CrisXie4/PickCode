import 'package:flutter/material.dart';
import '../services/update_service.dart';
import 'home_screen.dart';
import 'groups_screen.dart';
import 'settings_screen.dart';

/// 底部导航：首页 / 群组 / 我的
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int index = 0;
  final pages = const [HomeScreen(), GroupsScreen(), SettingsScreen()];

  @override
  void initState() {
    super.initState();
    // 启动后静默检查 GitHub 新版本，有更新才弹窗
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) UpdateService.promptIfAvailable(context, silent: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: pages[index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => setState(() => index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.inbox_outlined), selectedIcon: Icon(Icons.inbox), label: '我的快递'),
          NavigationDestination(icon: Icon(Icons.groups_outlined), selectedIcon: Icon(Icons.groups), label: '群组'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: '我的'),
        ],
      ),
    );
  }
}
