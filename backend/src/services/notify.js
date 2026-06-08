import { prisma } from '../prisma.js';
import { pushToUser } from './push.js';

/**
 * 创建通知（落库）+ 真实推送（FCM）。
 * @param {string} userId
 * @param {{type,title,body,data}} payload
 */
export async function createNotification(userId, { type, title, body = null, data = null }) {
  const notification = await prisma.notification.create({
    data: { userId, type, title, body, data: data ? JSON.stringify(data) : null },
  });
  // 触发真实推送（未配置 FCM 时自动跳过）
  pushToUser(userId, { title, body, data: { type, ...(data || {}) } }).catch(() => {});
  return notification;
}

/**
 * 群组广播：给群内开启通知、且非操作者本人的成员发通知
 */
export async function notifyGroupMembers(groupId, excludeUserId, payload) {
  const members = await prisma.groupMember.findMany({
    where: { groupId, notifyEnabled: true, userId: { not: excludeUserId } },
    select: { userId: true },
  });
  await Promise.all(members.map((m) => createNotification(m.userId, payload)));
}
