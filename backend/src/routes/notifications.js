import { Router } from 'express';
import { prisma } from '../prisma.js';
import { authRequired } from '../middleware/auth.js';
import { asyncH } from '../middleware/error.js';

export const notificationRouter = Router();
notificationRouter.use(authRequired);

// 我的通知列表
notificationRouter.get(
  '/',
  asyncH(async (req, res) => {
    const notifications = await prisma.notification.findMany({
      where: { userId: req.user.id },
      orderBy: { createdAt: 'desc' },
      take: 100,
    });
    const unread = notifications.filter((n) => !n.read).length;
    res.json({ notifications, unread });
  })
);

// 标记已读（单条或全部）
notificationRouter.post(
  '/read',
  asyncH(async (req, res) => {
    const { id } = req.body;
    await prisma.notification.updateMany({
      where: { userId: req.user.id, ...(id ? { id } : {}) },
      data: { read: true },
    });
    res.json({ ok: true });
  })
);
