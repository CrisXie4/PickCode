// 自动清除任务：保持数据精简，不占空间。
import { prisma } from '../prisma.js';

const DAY = 24 * 60 * 60 * 1000;

export async function runCleanup() {
  // 1) 已取件超过 3 天的个人快递 → 自动删除
  const removed = await prisma.parcel.deleteMany({
    where: { status: 'picked', updatedAt: { lt: new Date(Date.now() - 3 * DAY) } },
  });

  // 2) 待取件超过 15 天 → 自动标记为已过期
  await prisma.parcel.updateMany({
    where: { status: 'pending', createdAt: { lt: new Date(Date.now() - 15 * DAY) } },
    data: { status: 'expired' },
  });

  // 3) 已过期超过 7 天的共享记录 → 从群里清除
  await prisma.sharedParcel.deleteMany({
    where: { status: 'expired', createdAt: { lt: new Date(Date.now() - 7 * DAY) } },
  });

  if (removed.count) console.log(`🧹 自动清除已取件快递 ${removed.count} 条`);
}

// 启动时执行一次，之后每小时一次
export function startCleanupJob() {
  runCleanup().catch((e) => console.warn('cleanup 失败:', e.message));
  setInterval(() => runCleanup().catch(() => {}), 60 * 60 * 1000);
}
