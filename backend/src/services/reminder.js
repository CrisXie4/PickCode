// 自动催取任务：在免费时长内，定时提醒群成员（共享者除外）尽快取件。
import { prisma } from '../prisma.js';
import { notifyGroupMembers } from './notify.js';

const HOUR = 60 * 60 * 1000;
const FREE_HOURS = 24; // 一个快递免费时长 = 1 天
const EVERY = 2 * HOUR; // 每 2 小时催一次

/**
 * 扫描仍待取件、且还在免费时长（1 天）内的群内共享快递，
 * 给群里除共享者以外、且开启通知的成员发一条催取提醒。
 */
export async function runShareReminders() {
  const freeWindowStart = new Date(Date.now() - FREE_HOURS * HOUR);

  const shares = await prisma.sharedParcel.findMany({
    where: {
      status: 'pending', // 已取件（picked）/已过期（expired）的自动排除 → 不再催
      createdAt: { gte: freeWindowStart }, // 仅免费期（1 天）内，超时不再催
    },
    include: { parcel: true },
  });

  for (const s of shares) {
    await notifyGroupMembers(s.groupId, s.sharedById, {
      type: 'auto_remind',
      title: '快递还没取',
      body: `取件码 ${s.parcel.pickupCode} 还没取，免费时长快到了，帮忙顺手拿一下～`,
      data: { groupId: s.groupId, sharedId: s.id, parcelId: s.parcelId },
    });
  }

  if (shares.length) console.log(`⏰ 自动催取 ${shares.length} 条共享快递`);
}

// 每 2 小时执行一次（不在启动时立即跑，避免重启即刷一波通知）
export function startReminderJob() {
  setInterval(() => runShareReminders().catch((e) => console.warn('催取失败:', e.message)), EVERY);
}
