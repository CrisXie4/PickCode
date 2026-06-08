import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import '../models/models.dart';
import '../utils/text.dart';
import '../utils/errors.dart';
import '../widgets/states.dart';
import 'add_parcel_screen.dart';

/// 首页：显示我的快递。支持按状态筛选、复制取件码、标记取件、共享、删除。
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _api = ApiService();
  late Future<List<Parcel>> _future;
  String _filter = 'all'; // all / pending / picked / expired

  @override
  void initState() {
    super.initState();
    _future = _api.myParcels();
  }

  void _refresh() => setState(() => _future = _api.myParcels());

  static const _statusColors = {
    'pending': Color(0xFFF57C00),
    'picked': Color(0xFF2E7D32),
    'expired': Color(0xFF9E9E9E),
  };
  Color _statusColor(String s) => _statusColors[s] ?? Colors.grey;

  String _ago(DateTime? t) {
    if (t == null) return '';
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return '刚刚';
    if (d.inMinutes < 60) return '${d.inMinutes} 分钟前';
    if (d.inHours < 24) return '${d.inHours} 小时前';
    if (d.inDays < 30) return '${d.inDays} 天前';
    return '${t.year}/${t.month}/${t.day}';
  }

  void _toast(String msg) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _copyCode(String code) async {
    await Clipboard.setData(ClipboardData(text: code));
    _toast('取件码已复制：$code');
  }

  Future<void> _markPicked(Parcel p) async {
    try {
      await _api.updateParcel(p.id, {'status': p.status == 'picked' ? 'pending' : 'picked'});
      _toast(p.status == 'picked' ? '已恢复为待取件' : '已标记取件 ✓');
      _refresh();
    } catch (e) {
      _toast(friendlyError(e));
    }
  }

  Future<void> _delete(Parcel p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('删除快递'),
        content: Text('确定删除取件码「${p.pickupCode}」？此操作不可恢复。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade600),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _api.deleteParcel(p.id);
      _toast('已删除');
      _refresh();
    } catch (e) {
      _toast(friendlyError(e));
    }
  }

  Future<void> _share(Parcel p) async {
    List<Group> groups;
    try {
      groups = await _api.myGroups();
    } catch (e) {
      _toast(friendlyError(e));
      return;
    }
    if (!mounted) return;
    if (groups.isEmpty) {
      _toast('你还没有加入任何群组');
      return;
    }
    final picked = await showModalBottomSheet<Group>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('共享到哪个群？', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            ...groups.map((g) => ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.groups)),
                  title: Text(g.name),
                  subtitle: Text('${g.memberCount} 人'),
                  onTap: () => Navigator.pop(context, g),
                )),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (picked == null) return;
    try {
      await _api.shareToGroup(p.id, picked.id);
      _toast('已共享到「${picked.name}」');
    } catch (e) {
      _toast(friendlyError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('我的快递')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final added = await Navigator.push<bool>(
            context,
            MaterialPageRoute(builder: (_) => const AddParcelScreen()),
          );
          if (added == true) _refresh();
        },
        icon: const Icon(Icons.add),
        label: const Text('添加快递'),
      ),
      body: RefreshIndicator(
        onRefresh: () async => _refresh(),
        child: FutureBuilder<List<Parcel>>(
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
            final all = snap.data ?? [];
            if (all.isEmpty) {
              return const EmptyState(
                icon: Icons.inbox_outlined,
                title: '还没有快递',
                subtitle: '点右下角「添加快递」记录一个吧 👇',
              );
            }

            final counts = {
              'all': all.length,
              'pending': all.where((p) => p.status == 'pending').length,
              'picked': all.where((p) => p.status == 'picked').length,
              'expired': all.where((p) => p.status == 'expired').length,
            };
            final list = _filter == 'all' ? all : all.where((p) => p.status == _filter).toList();

            return Column(
              children: [
                _FilterBar(filter: _filter, counts: counts, onChanged: (f) => setState(() => _filter = f)),
                Expanded(
                  child: list.isEmpty
                      ? EmptyState(icon: Icons.filter_alt_off, title: '该分类下暂无快递', iconColor: Colors.grey.shade300)
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(12, 4, 12, 88),
                          itemCount: list.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (context, i) => _parcelCard(list[i]),
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _parcelCard(Parcel p) {
    final color = _statusColor(p.status);
    final subtitle = [
      if (p.company?.isNotEmpty ?? false) p.company,
      if (p.location?.isNotEmpty ?? false) p.location,
      if (p.locker?.isNotEmpty ?? false) '柜:${p.locker}',
    ].join(' · ');

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            CircleAvatar(
              backgroundColor: color.withValues(alpha: 0.14),
              foregroundColor: color,
              child: Text(initial(p.company, '快')),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          p.pickupCode,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      InkWell(
                        onTap: () => _copyCode(p.pickupCode),
                        borderRadius: BorderRadius.circular(6),
                        child: Padding(
                          padding: const EdgeInsets.all(3),
                          child: Icon(Icons.copy, size: 15, color: Colors.grey.shade500),
                        ),
                      ),
                    ],
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(subtitle, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                  ],
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
                        child: Text(Parcel.statusLabels[p.status] ?? p.status, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
                      ),
                      const SizedBox(width: 8),
                      Text(_ago(p.createdAt), style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, color: Colors.grey.shade500),
              onSelected: (v) {
                if (v == 'pick') _markPicked(p);
                if (v == 'share') _share(p);
                if (v == 'delete') _delete(p);
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'pick',
                  child: Row(children: [
                    Icon(p.status == 'picked' ? Icons.undo : Icons.check_circle, size: 19, color: Colors.green),
                    const SizedBox(width: 10),
                    Text(p.status == 'picked' ? '恢复待取件' : '标记已取件'),
                  ]),
                ),
                const PopupMenuItem(
                  value: 'share',
                  child: Row(children: [Icon(Icons.share, size: 19), SizedBox(width: 10), Text('共享到群')]),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Row(children: [
                    Icon(Icons.delete_outline, size: 19, color: Colors.red.shade600),
                    const SizedBox(width: 10),
                    Text('删除', style: TextStyle(color: Colors.red.shade600)),
                  ]),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 顶部状态筛选条
class _FilterBar extends StatelessWidget {
  final String filter;
  final Map<String, int> counts;
  final ValueChanged<String> onChanged;
  const _FilterBar({required this.filter, required this.counts, required this.onChanged});

  static const _tabs = [
    ('all', '全部'),
    ('pending', '待取件'),
    ('picked', '已取件'),
    ('expired', '已过期'),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        children: _tabs.map((t) {
          final selected = filter == t.$1;
          final n = counts[t.$1] ?? 0;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text('${t.$2}${n > 0 ? ' $n' : ''}'),
              selected: selected,
              onSelected: (_) => onChanged(t.$1),
              showCheckmark: false,
              labelStyle: TextStyle(
                color: selected ? Theme.of(context).colorScheme.primary : Colors.grey.shade700,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              ),
              backgroundColor: Colors.white,
              selectedColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
              side: BorderSide(color: selected ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.3) : Colors.grey.shade200),
            ),
          );
        }).toList(),
      ),
    );
  }
}
