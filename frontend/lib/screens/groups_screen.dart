import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/models.dart';
import '../utils/errors.dart';
import '../widgets/states.dart';
import 'group_detail_screen.dart';

/// 群组列表页：我加入的群 + 创建群 + 通过邀请码加群
class GroupsScreen extends StatefulWidget {
  const GroupsScreen({super.key});
  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> {
  final _api = ApiService();
  late Future<List<Group>> _future;

  @override
  void initState() {
    super.initState();
    _future = _api.myGroups();
  }

  void _refresh() => setState(() => _future = _api.myGroups());

  Future<void> _createDialog() async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('创建群组'),
        content: TextField(controller: ctrl, decoration: const InputDecoration(hintText: '群名，如“宿舍群”')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('创建')),
        ],
      ),
    );
    if (ok == true && ctrl.text.trim().isNotEmpty) {
      try {
        await _api.createGroup(ctrl.text.trim());
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('群组已创建')));
        _refresh();
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
      }
    }
  }

  Future<void> _joinDialog() async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('输入邀请码加群'),
        content: TextField(controller: ctrl, decoration: const InputDecoration(hintText: '8 位邀请码')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('申请加入')),
        ],
      ),
    );
    if (ok == true && ctrl.text.trim().isNotEmpty) {
      try {
        await _api.joinByCode(ctrl.text.trim());
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已提交申请，等待群主审核')));
        }
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('群组'),
        actions: [
          IconButton(onPressed: _joinDialog, icon: const Icon(Icons.group_add), tooltip: '邀请码加群'),
          IconButton(onPressed: _createDialog, icon: const Icon(Icons.add), tooltip: '创建群组'),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => _refresh(),
        child: FutureBuilder<List<Group>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const LoadingState(message: '加载中…');
            }
            if (snap.hasError) {
              return EmptyState(
                icon: Icons.cloud_off,
                title: friendlyError(snap.error),
                subtitle: '请检查网络后重试',
                actionLabel: '重试',
                onAction: _refresh,
              );
            }
            final groups = snap.data ?? [];
            if (groups.isEmpty) {
              return const EmptyState(
                icon: Icons.groups_outlined,
                title: '还没有群组',
                subtitle: '点右上角创建群组，或用邀请码加入',
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: groups.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final g = groups[i];
                final isOwner = g.role == 'owner';
                return Card(
                  child: ListTile(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    leading: CircleAvatar(
                      backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                      foregroundColor: Theme.of(context).colorScheme.primary,
                      child: const Icon(Icons.groups),
                    ),
                    title: Text(g.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text('${g.memberCount} 人'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isOwner)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(color: const Color(0xFFFFF3E0), borderRadius: BorderRadius.circular(6)),
                            child: const Text('群主', style: TextStyle(color: Color(0xFFE65100), fontSize: 12, fontWeight: FontWeight.w600)),
                          ),
                        const SizedBox(width: 4),
                        Icon(Icons.chevron_right, color: Colors.grey.shade400),
                      ],
                    ),
                    onTap: () async {
                      await Navigator.push(context, MaterialPageRoute(builder: (_) => GroupDetailScreen(group: g)));
                      _refresh();
                    },
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
