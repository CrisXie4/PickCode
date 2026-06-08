import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import '../models/models.dart';
import '../utils/text.dart';
import '../utils/errors.dart';

/// 群详情页：邀请码、成员、群内共享快递、群主审批入口、通知开关
class GroupDetailScreen extends StatefulWidget {
  final Group group;
  const GroupDetailScreen({super.key, required this.group});
  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen> {
  final _api = ApiService();
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = _api.groupDetail(widget.group.id);
  }

  void _refresh() => setState(() => _future = _api.groupDetail(widget.group.id));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.group.name),
        actions: [
          if (widget.group.role == 'owner')
            IconButton(
              icon: const Icon(Icons.how_to_reg),
              tooltip: '加群申请',
              onPressed: () => _openRequests(),
            ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final data = snap.data!;
          final group = data['group'];
          final members = (group['members'] as List?) ?? [];
          final shared = (group['sharedParcels'] as List?) ?? [];
          final notifyEnabled = data['notifyEnabled'] ?? true;

          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              // 邀请码
              Card(
                child: ListTile(
                  leading: const Icon(Icons.qr_code),
                  title: Text('邀请码：${group['inviteCode']}'),
                  subtitle: const Text('分享给好友，对方申请后由群主审核'),
                  trailing: IconButton(
                    icon: const Icon(Icons.copy),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: group['inviteCode']));
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已复制邀请码')));
                    },
                  ),
                ),
              ),
              // 群通知开关
              SwitchListTile(
                title: const Text('接收本群通知'),
                value: notifyEnabled,
                onChanged: (v) async {
                  await _api.toggleNotify(widget.group.id, v);
                  _refresh();
                },
              ),
              const Divider(),
              Text('成员 (${members.length})', style: const TextStyle(fontWeight: FontWeight.bold)),
              ...members.map((m) {
                final u = m['user'];
                final isOwner = m['role'] == 'owner';
                return ListTile(
                  dense: true,
                  leading: CircleAvatar(child: Text(initial(u['nickname']))),
                  title: Text(u['nickname'] ?? ''),
                  subtitle: Text(isOwner ? '群主' : '成员'),
                  trailing: (widget.group.role == 'owner' && !isOwner)
                      ? IconButton(
                          icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                          onPressed: () async {
                            await _api.removeMember(widget.group.id, u['id']);
                            _refresh();
                          },
                        )
                      : null,
                );
              }),
              const Divider(),
              Text('群内共享快递 (${shared.length})', style: const TextStyle(fontWeight: FontWeight.bold)),
              if (shared.isEmpty) const Padding(padding: EdgeInsets.all(16), child: Text('暂无共享，去“我的快递”里共享一条吧')),
              ...shared.map((s) {
                final p = s['parcel'];
                final by = s['sharedBy'];
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('取件码：${p['pickupCode']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 4),
                        Text([
                          if (p['company'] != null) p['company'],
                          if (p['location'] != null) p['location'],
                          '由 ${by['nickname']} 共享',
                          if (s['note'] != null) '备注：${s['note']}',
                        ].join('\n'), style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                        // 操作按钮独立成行，确保都能正常点击
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton.icon(
                              icon: const Icon(Icons.notifications_active, size: 18),
                              label: const Text('提醒'),
                              onPressed: () async {
                                try {
                                  await _api.remindShared(widget.group.id, s['id']);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已发送提醒')));
                                  }
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
                                  }
                                }
                              },
                            ),
                            TextButton.icon(
                              icon: const Icon(Icons.check_circle, size: 18, color: Colors.green),
                              label: const Text('已取件', style: TextStyle(color: Colors.green)),
                              onPressed: () async {
                                try {
                                  await _api.markSharedPicked(widget.group.id, s['id']);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('已标记取件，发起人已收到通知')),
                                    );
                                  }
                                  _refresh(); // 该共享记录已清除，刷新后消失
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
                                  }
                                }
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }

  // 加群申请管理页（群主）
  Future<void> _openRequests() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => _JoinRequestsScreen(api: _api, groupId: widget.group.id)),
    );
    _refresh();
  }
}

/// 加群申请管理页
class _JoinRequestsScreen extends StatefulWidget {
  final ApiService api;
  final String groupId;
  const _JoinRequestsScreen({required this.api, required this.groupId});
  @override
  State<_JoinRequestsScreen> createState() => _JoinRequestsScreenState();
}

class _JoinRequestsScreenState extends State<_JoinRequestsScreen> {
  late Future<List<dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.api.joinRequests(widget.groupId);
  }

  void _refresh() => setState(() => _future = widget.api.joinRequests(widget.groupId));

  Future<void> _review(String requestId, String action) async {
    await widget.api.reviewRequest(widget.groupId, requestId, action);
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('加群申请')),
      body: FutureBuilder<List<dynamic>>(
        future: _future,
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final requests = snap.data!;
          if (requests.isEmpty) return const Center(child: Text('暂无待审申请'));
          return ListView(
            children: requests.map((r) {
              final u = r['user'];
              return ListTile(
                leading: CircleAvatar(child: Text(initial(u['nickname']))),
                title: Text(u['nickname'] ?? ''),
                subtitle: Text(r['message'] ?? '申请加入'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.check_circle, color: Colors.green),
                      onPressed: () => _review(r['id'], 'approve'),
                    ),
                    IconButton(
                      icon: const Icon(Icons.cancel, color: Colors.red),
                      onPressed: () => _review(r['id'], 'reject'),
                    ),
                  ],
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}
