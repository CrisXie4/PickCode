// 冒烟测试：验证应用根 widget 能正常构建。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:express_pickup/main.dart';
import 'package:express_pickup/providers/auth_provider.dart';

void main() {
  testWidgets('App builds without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AuthProvider(),
        child: const ExpressApp(),
      ),
    );

    // 根 MaterialApp 渲染成功
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
