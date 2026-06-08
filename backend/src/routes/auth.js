import { Router } from 'express';
import bcrypt from 'bcryptjs';
import { z } from 'zod';
import { prisma } from '../prisma.js';
import { signToken } from '../utils/jwt.js';
import { asyncH } from '../middleware/error.js';

export const authRouter = Router();

const registerSchema = z
  .object({
    phone: z.string().min(6).optional(),
    email: z.string().email().optional(),
    password: z.string().min(6),
    nickname: z.string().min(1).max(20).optional(),
  })
  .refine((d) => d.phone || d.email, { message: '手机号或邮箱至少填一个' });

// 注册（无需短信验证码）
authRouter.post(
  '/register',
  asyncH(async (req, res) => {
    const data = registerSchema.parse(req.body);
    const passwordHash = await bcrypt.hash(data.password, 10);
    const user = await prisma.user.create({
      data: {
        phone: data.phone || null,
        email: data.email || null,
        passwordHash,
        nickname: data.nickname || (data.phone || data.email).slice(0, 6),
      },
    });
    const token = signToken({ sub: user.id });
    res.json({ token, user: publicUser(user) });
  })
);

// 登录：account 可为手机号或邮箱
authRouter.post(
  '/login',
  asyncH(async (req, res) => {
    const { account, password } = z
      .object({ account: z.string(), password: z.string() })
      .parse(req.body);

    const user = await prisma.user.findFirst({
      where: { OR: [{ phone: account }, { email: account }] },
    });
    if (!user) return res.status(401).json({ message: '账号不存在' });

    const ok = await bcrypt.compare(password, user.passwordHash);
    if (!ok) return res.status(401).json({ message: '密码错误' });

    const token = signToken({ sub: user.id });
    res.json({ token, user: publicUser(user) });
  })
);

export function publicUser(u) {
  return {
    id: u.id,
    phone: u.phone,
    email: u.email,
    nickname: u.nickname,
    avatarUrl: u.avatarUrl,
    isAdmin: u.isAdmin,
  };
}
