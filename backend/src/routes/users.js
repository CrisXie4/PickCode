import { Router } from 'express';
import { z } from 'zod';
import { prisma } from '../prisma.js';
import { authRequired } from '../middleware/auth.js';
import { asyncH } from '../middleware/error.js';
import { publicUser } from './auth.js';

export const userRouter = Router();
userRouter.use(authRequired);

// 当前用户信息
userRouter.get('/me', (req, res) => res.json({ user: publicUser(req.user) }));

// 修改昵称 / 头像
userRouter.patch(
  '/me',
  asyncH(async (req, res) => {
    const data = z
      .object({ nickname: z.string().min(1).max(20).optional(), avatarUrl: z.string().url().optional() })
      .parse(req.body);
    const user = await prisma.user.update({ where: { id: req.user.id }, data });
    res.json({ user: publicUser(user) });
  })
);

// 注册推送设备 token（客户端拿到 FCM token 后上报）
userRouter.post(
  '/device-token',
  asyncH(async (req, res) => {
    const { token, platform } = z
      .object({ token: z.string().min(1), platform: z.enum(['ios', 'android']).optional() })
      .parse(req.body);
    await prisma.deviceToken.upsert({
      where: { token },
      update: { userId: req.user.id, platform: platform || 'android' },
      create: { token, userId: req.user.id, platform: platform || 'android' },
    });
    res.json({ ok: true });
  })
);
