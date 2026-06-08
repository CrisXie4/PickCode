# 真实推送 & 跨平台说明

## 一、各平台开发需要下载/准备什么

| 你要做的事 | 需要的东西 | 你现在的 Windows 能做吗 |
|-----------|-----------|----------------------|
| 后端开发/运行 | Node.js（已装 v24） | ✅ 能 |
| Android App 开发/测试 | Flutter SDK + Android Studio | ✅ 能 |
| **iOS App 开发/测试/上架** | **一台 Mac + Xcode + Apple 开发者账号($99/年)** | ❌ Windows 不能编译 iOS |
| 真实推送 | Firebase 项目（免费） + iOS 还需 APNs 密钥 | ✅ 配置能做 |

### 必装清单（Android 开发）
1. **Flutter SDK**：https://docs.flutter.dev/get-started/install/windows
2. **Android Studio**（含 Android SDK、模拟器）
3. 装完执行 `flutter doctor` 检查环境

### iOS 怎么办（没有 Mac 时的选项）
- 借/买一台 Mac，或用**云端 Mac 构建服务**（如 Codemagic、Mac in Cloud）
- 用 **Codemagic CI** 可以在云上自动构建 iOS 包，但装到真机/上架仍需 Apple 开发者账号
- 代码本身无需为 iOS 改动，Flutter 一套代码两端通用

---

## 二、真实推送（FCM）配置

后端已内置 FCM 支持（`src/services/push.js`），**未配置时自动降级为仅落库**，配置后即真实推送。Android 和 iOS 都走 FCM。

### 后端
1. 打开 [Firebase 控制台](https://console.firebase.google.com/) → 新建项目
2. 项目设置 → 服务账号 → 生成新私钥 → 下载 JSON
3. 把 JSON 放到 `backend/firebase-service-account.json`
4. `.env` 里取消注释：`FIREBASE_SERVICE_ACCOUNT="./firebase-service-account.json"`
5. `npm install firebase-admin`（已在 package.json）
6. 重启后端，看到 `✅ FCM 推送已启用` 即成功

### Flutter 客户端（Android）

> Gradle 接线已预先做好（`settings.gradle.kts` 与 `app/build.gradle.kts` 已应用
> `com.google.gms.google-services` 插件），你**只需放入 `google-services.json`** 即可，无需改 Gradle。

1. Firebase 控制台 → 项目 → 添加 **Android 应用**，
   **包名(package name)必须填 `com.example.express_pickup`**（与 `app/build.gradle.kts` 的 `applicationId` 一致，否则推送拿不到 token）
2. 下载该应用的 `google-services.json`，放到 `frontend/android/app/google-services.json`
3. `flutter pub get` → `flutter build apk --release` 重新打包
4. 代码已写好：登录后 `PushService.setup()` 自动申请通知权限、拿 FCM token、上报后端 `/users/device-token`

> 注：本项目仅 Android-only 时**不需要** `flutterfire configure` / `firebase_options.dart`——
> `Firebase.initializeApp()` 会直接读取 `google-services.json` 生成的资源。
> 若以后要出 iOS，再用 `flutterfire configure` 一并生成 iOS 配置。

### iOS（需 Mac）
- 在 Firebase 上传 **APNs 鉴权密钥**（Apple 开发者后台生成 .p8），并放入 `GoogleService-Info.plist`

---

## 三、手动提醒（已实现，无需推送也能用）

除了管理员「一键提醒所有人」，普通用户也能手动提醒：

- **谁能提醒**：群内任意成员
- **在哪**：群详情页 → 每条共享快递右侧「🔔 提醒」按钮
- **逻辑**：
  - 你是这条快递的共享者 → 广播给群里其他人「帮我顺手拿一下」
  - 你不是共享者 → 提醒共享者本人「该取件了」
- **接口**：`POST /api/groups/:id/shared/:sharedId/remind`
- 提醒会落库成通知；若配置了 FCM，则同时弹真实系统推送

> 已通过端到端实测：成员提醒 → 共享者收到「XX 提醒你：取件码 XX 该取啦」。
