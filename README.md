# 快递取件协作 App（Express Pickup）

一个跨平台（Android / iOS）的快递取件协作应用。支持快递智能识别、群组共享取件、通知提醒、管理后台。

后端（Node.js + Express + Prisma）**已可直接运行并通过端到端验证**；前端为 Flutter 工程骨架（含全部核心页面与 API 对接）。

---

## 一、整体架构

```
┌─────────────────────┐      HTTPS / JSON       ┌──────────────────────┐
│   Flutter App        │  ───────────────────►   │   Node.js (Express)   │
│  Android / iOS       │   Bearer JWT 鉴权        │   REST API            │
│                      │  ◄───────────────────   │                       │
│  · Provider 状态管理   │                         │  · JWT 登录/权限校验    │
│  · Dio 网络层         │                         │  · 业务路由            │
│  · 本地 OCR(MLKit)    │                         │  · 智能识别 parser     │
│  · 本地通知           │                         │  · 通知服务            │
└─────────────────────┘                         └──────────┬───────────┘
                                                            │ Prisma ORM
┌─────────────────────┐                          ┌──────────▼───────────┐
│  Web 管理后台         │  ───────────────────►   │  SQLite / PostgreSQL  │
│  (单文件 HTML)        │     /api/admin/*        │  数据库               │
└─────────────────────┘                          └──────────────────────┘
```

模块划分：用户系统、快递管理、智能识别、群组协作、群内共享、通知、管理后台。

---

## 二、技术选型理由

| 层 | 选型 | 理由 |
|----|------|------|
| 前端 | **Flutter** | 一套 Dart 代码同时出 Android/iOS，热重载开发快，UI 一致性好；生态有现成的本地 OCR、本地通知插件。 |
| 后端 | **Node.js + Express** | 快递这类 IO 密集型应用非常适合 Node；Express 轻量、上手快、社区成熟，最适合快速开发 MVP。 |
| ORM | **Prisma** | 类型安全、迁移工具完善、schema 即文档；切换 SQLite↔PostgreSQL 仅改一行。 |
| 数据库 | **SQLite（默认）→ PostgreSQL（生产）** | SQLite 零配置、开箱即跑，适合开发期；上线换 PostgreSQL 一行配置即可，无需改模型。 |
| 鉴权 | **JWT** | 无状态、移动端友好、易水平扩展。 |
| 智能识别 | **规则 parser（正则）** | 零依赖、可离线、对中文快递短信格式覆盖好；后续可叠加 NLP/大模型。 |
| OCR | **google_mlkit_text_recognition** | 端侧离线识别，截图转文本不上传图片，隐私友好。 |

---

## 三、快速开始

### 后端
```bash
cd backend
cp .env.example .env          # 配置环境变量（默认 SQLite 开箱即用）
npm install
npx prisma migrate dev --name init   # 建表
node prisma/seed.js           # 初始化管理员账号
npm run dev                   # 启动：http://localhost:3000
```

- 管理后台：浏览器打开 `http://localhost:3000/admin/`
- 默认管理员：`admin@express.local` / `admin123456`

### 前端
```bash
cd frontend
flutter pub get
flutter run                   # 连真机/模拟器运行
```
> Android 模拟器访问本机后端用 `10.0.2.2`；真机改 `lib/services/api_client.dart` 里的 `baseUrl` 为电脑局域网 IP。

---

## 四、目录结构

详见 [docs/STRUCTURE.md](docs/STRUCTURE.md)、[docs/API.md](docs/API.md)、[docs/DATABASE.md](docs/DATABASE.md)。

---

## 五、已实现 & 后续步骤

详见 [docs/ROADMAP.md](docs/ROADMAP.md)。

---

## 六、友情链接

[![LINUX DO](https://img.shields.io/badge/LINUX%20DO-新的理想型社区-ffb003?style=for-the-badge)](https://linux.do)

> [LINUX DO](https://linux.do) —— 新的理想型社区，欢迎来玩 👋
