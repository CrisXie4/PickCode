import { ZodError } from 'zod';

// 统一错误处理
export function errorHandler(err, req, res, next) {
  if (err instanceof ZodError) {
    return res.status(400).json({ message: '参数校验失败', errors: err.flatten() });
  }
  // Prisma 唯一约束冲突
  if (err.code === 'P2002') {
    return res.status(409).json({ message: '数据已存在（唯一字段冲突）', fields: err.meta?.target });
  }
  console.error(err);
  res.status(err.status || 500).json({ message: err.message || '服务器内部错误' });
}

// 包裹 async 路由，自动捕获异常
export const asyncH = (fn) => (req, res, next) => Promise.resolve(fn(req, res, next)).catch(next);
