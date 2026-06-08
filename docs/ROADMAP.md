# 已实现 & 后续开发步骤

## ✅ 已实现并通过端到端验证（后端）
- 用户注册/登录（手机号/邮箱，无验证码）、JWT 鉴权、改昵称/头像、退出
- 快递增删改查、状态流转（待取件/已取件/已过期）
- 智能识别 parser：从短信/剪贴板/OCR文本提取 公司/取件码/取件柜/位置（测试置信度 1.0）
- 群组：创建、邀请码、申请加群、群主审批、移除成员、群通知开关
- 群内共享：共享快递、成员可见、共享备注、状态标记、显示共享人
- 通知：新取件码、群共享、加群申请、审批结果、管理员提醒
- 权限隔离：个人快递仅本人可见，群数据仅成员可见
- 管理后台：统计、查看所有取件码、一键提醒所有待取件用户

> 验证记录：登录、识别、加快递+通知、完整群组流程（创建→邀请码→申请→审批→共享→成员可见）、管理后台统计与一键提醒均实测通过。

## ✅ 已实现（前端 Flutter 骨架）
- 全部 8 个核心页面 + 底部导航 + 登录态路由
- Dio 网络层（token 自动注入）、Provider 状态管理
- 剪贴板识别、截图 OCR（MLKit）对接

## 🔜 后续开发步骤（建议顺序）

### 第 1 步：前端联调跑通
- `flutter pub get` 后连真机/模拟器；按平台改 `baseUrl`
- 走通注册→加快递→识别→建群→共享全流程

### 第 2 步：真实推送
- 当前通知已落库，App 端轮询/进入时拉取。接入 **FCM(Android) / APNs(iOS)** 或极光推送：
  - 在 `services/notify.js` 的 `createNotification` 里追加推送调用
  - 客户端用 `flutter_local_notifications` 展示前台通知，注册 device token 存到 User 表

### 第 3 步：短信自动识别（Android）
- Android 申请 `RECEIVE_SMS` 权限，监听快递短信 → 调 `/recognition/parse` → 弹确认
- iOS 无法读短信，走"分享菜单/剪贴板/截图"路径

### 第 4 步：识别算法增强
- `parser.js` 现为规则版。可叠加：更多快递模板、地址 NLP、或接大模型做兜底解析
- 加单元测试覆盖各家快递短信格式

### 第 5 步：生产化
- 数据库切 PostgreSQL（改 `schema.prisma` 的 provider + `DATABASE_URL`）
- 头像改对象存储（OSS/S3）+ 上传接口；JWT_SECRET 换强随机；加 HTTPS、限流、日志
- 后端容器化（Dockerfile）部署；前端打包上架

### 第 6 步：体验增强
- 取件码二维码/条码展示、一键复制
- 群内 @提醒、"已帮取"回执
- 快递过期自动置 expired（定时任务）
- 暗黑模式、多语言

## 数据库迁移到 PostgreSQL
```prisma
datasource db {
  provider = "postgresql"
  url      = env("DATABASE_URL")
}
```
```bash
# .env
DATABASE_URL="postgresql://user:pass@localhost:5432/express_pickup?schema=public"
npx prisma migrate dev --name init
```
模型无需任何改动。
