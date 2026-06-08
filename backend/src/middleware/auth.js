import { verifyToken } from '../utils/jwt.js';
import { prisma } from '../prisma.js';

// 登录校验：解析 Bearer token，挂载 req.user
export async function authRequired(req, res, next) {
  try {
    const header = req.headers.authorization || '';
    const token = header.startsWith('Bearer ') ? header.slice(7) : null;
    if (!token) return res.status(401).json({ message: '未登录' });

    const decoded = verifyToken(token);
    const user = await prisma.user.findUnique({ where: { id: decoded.sub } });
    if (!user) return res.status(401).json({ message: '用户不存在' });

    req.user = user;
    next();
  } catch (e) {
    return res.status(401).json({ message: 'token 无效或已过期' });
  }
}

// 管理后台权限校验
export function adminRequired(req, res, next) {
  if (!req.user?.isAdmin) return res.status(403).json({ message: '需要管理员权限' });
  next();
}
