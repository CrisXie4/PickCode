// 真实推送：FCM（Firebase Cloud Messaging），同时覆盖 Android 和 iOS。
// 未配置 Firebase 时自动降级为"仅落库 + 控制台日志"，不影响其它功能运行。
//
// 启用步骤（见 docs/PUSH.md）：
//   1. Firebase 控制台创建项目，下载服务账号私钥 JSON
//   2. .env 配置 FIREBASE_SERVICE_ACCOUNT=./firebase-service-account.json
//   3. npm install firebase-admin
import { readFileSync } from 'fs';
import { prisma } from '../prisma.js';

let messaging = null;

async function initFirebase() {
  const saPath = process.env.FIREBASE_SERVICE_ACCOUNT;
  if (!saPath) {
    console.log('ℹ️  未配置 FIREBASE_SERVICE_ACCOUNT，推送仅落库（开发模式）');
    return;
  }
  try {
    const admin = (await import('firebase-admin')).default;
    const sa = JSON.parse(readFileSync(saPath, 'utf-8'));
    admin.initializeApp({ credential: admin.credential.cert(sa) });
    messaging = admin.messaging();
    console.log('✅ FCM 推送已启用');
  } catch (e) {
    console.warn('⚠️  FCM 初始化失败，推送降级为仅落库：', e.message);
  }
}
initFirebase();

/**
 * 推送给某个用户的所有设备
 */
export async function pushToUser(userId, { title, body, data }) {
  if (!messaging) return; // 未配置则跳过真实推送
  const tokens = await prisma.deviceToken.findMany({
    where: { userId },
    select: { token: true },
  });
  if (tokens.length === 0) return;

  try {
    const res = await messaging.sendEachForMulticast({
      tokens: tokens.map((t) => t.token),
      notification: { title, body: body || '' },
      data: data
        ? Object.fromEntries(Object.entries(data).map(([k, v]) => [k, String(v)]))
        : undefined,
    });
    // 清理失效 token
    res.responses.forEach((r, i) => {
      if (!r.success && r.error?.code === 'messaging/registration-token-not-registered') {
        prisma.deviceToken.deleteMany({ where: { token: tokens[i].token } }).catch(() => {});
      }
    });
  } catch (e) {
    console.warn('推送失败：', e.message);
  }
}
