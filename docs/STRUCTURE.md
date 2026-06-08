# 项目目录结构

```
Express box/
├── README.md                 项目总览
├── docs/                     文档
│   ├── API.md                API 接口设计
│   ├── DATABASE.md           数据库设计
│   ├── STRUCTURE.md          本文件
│   └── ROADMAP.md            已实现 & 后续开发步骤
│
├── backend/                  后端（Node.js + Express + Prisma）✅ 可运行
│   ├── package.json
│   ├── .env.example          环境变量模板
│   ├── prisma/
│   │   ├── schema.prisma     数据库模型
│   │   └── seed.js           初始化管理员/示例数据
│   ├── public/
│   │   └── index.html        Web 管理后台（/admin/）
│   └── src/
│       ├── index.js          应用入口、路由挂载
│       ├── config.js         配置
│       ├── prisma.js         Prisma 单例
│       ├── middleware/
│       │   ├── auth.js        登录校验 + 管理员校验
│       │   └── error.js       统一错误处理
│       ├── utils/
│       │   ├── jwt.js         JWT 签发/校验
│       │   └── parser.js      快递信息智能识别（核心算法）
│       ├── services/
│       │   └── notify.js      通知服务（落库 + 群广播）
│       └── routes/
│           ├── auth.js        注册/登录
│           ├── users.js       用户资料
│           ├── parcels.js     快递 + 共享
│           ├── groups.js      群组 + 申请审批 + 成员
│           ├── recognition.js 智能识别
│           ├── notifications.js 通知
│           └── admin.js       管理后台 API
│
└── frontend/                 前端（Flutter）
    ├── pubspec.yaml
    └── lib/
        ├── main.dart                入口 + 登录态路由
        ├── models/
        │   └── models.dart          数据模型
        ├── services/
        │   ├── api_client.dart      Dio + token 拦截器
        │   ├── api_service.dart     所有接口封装
        │   └── models_import.dart   barrel
        ├── providers/
        │   └── auth_provider.dart   全局登录态
        └── screens/
            ├── login_screen.dart           登录/注册页
            ├── home_shell.dart             底部导航
            ├── home_screen.dart            首页：我的快递
            ├── add_parcel_screen.dart      添加快递 + 智能识别确认
            ├── groups_screen.dart          群组列表 + 创建/加群
            ├── group_detail_screen.dart    群详情 + 共享 + 加群申请管理
            └── settings_screen.dart        个人设置
```

## 页面 ↔ 需求对应
| 需求页面 | 文件 |
|----------|------|
| 登录/注册页 | `login_screen.dart` |
| 首页（我的快递） | `home_screen.dart` |
| 添加快递页 | `add_parcel_screen.dart` |
| 智能识别确认页 | 内联于 `add_parcel_screen.dart`（识别后回填表单确认） |
| 群组列表页 | `groups_screen.dart` |
| 群组详情页 | `group_detail_screen.dart` |
| 加群申请管理页 | `group_detail_screen.dart` 内 `_JoinRequestsScreen` |
| 个人设置页 | `settings_screen.dart` |
