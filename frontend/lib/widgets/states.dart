import 'package:flutter/material.dart';

/// 统一的加载中状态。
class LoadingState extends StatelessWidget {
  final String? message;
  const LoadingState({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          if (message != null) ...[
            const SizedBox(height: 14),
            Text(message!, style: TextStyle(color: Colors.grey.shade600)),
          ],
        ],
      ),
    );
  }
}

/// 统一的空状态 / 错误状态：图标 + 标题 + 说明 + 可选操作按钮。
/// 用 ListView 包裹以兼容 RefreshIndicator 下拉刷新。
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Color? iconColor;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const SizedBox(height: 100),
        Icon(icon, size: 64, color: iconColor ?? Colors.grey.shade300),
        const SizedBox(height: 16),
        Center(
          child: Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 6),
          Center(child: Text(subtitle!, style: TextStyle(color: Colors.grey.shade500))),
        ],
        if (actionLabel != null && onAction != null) ...[
          const SizedBox(height: 20),
          Center(
            child: OutlinedButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.refresh, size: 18),
              label: Text(actionLabel!),
            ),
          ),
        ],
      ],
    );
  }
}
