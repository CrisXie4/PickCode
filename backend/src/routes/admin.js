import { Router } from 'express';
import { z } from 'zod';
import bcrypt from 'bcryptjs';
import { prisma } from '../prisma.js';
import { authRequired, adminRequired } from '../middleware/auth.js';
import { asyncH } from '../middleware/error.js';
import { notifyGroupMembers, createNotification } from '../services/notify.js';

export const adminRouter = Router();
adminRouter.use(authRequired, adminRequired);

// 分页参数解析
function pageParams(req) {
  const page = Math.max(1, Number(req.query.page) || 1);
  const pageSize = Math.min(100, Math.max(1, Number(req.query.pageSize) || 20));
  return { page, pageSize, skip: (page - 1) * pageSize, take: pageSize };
}

// ==================== 概览统计 ====================
adminRouter.get(
  '/stats',
  asyncH(async (req, res) => {
    const [users, parcels, groups, pending] = await Promise.all([
      prisma.user.count(),
      prisma.parcel.count(),
      prisma.group.count(),
      prisma.parcel.count({ where: { status: 'pending' } }),
    ]);
    res.json({ users, parcels, groups, pendingParcels: pending });
  })
);

// ==================== 用户管理 ====================

// 用户列表（分页 + 搜索昵称/手机/邮箱）
adminRouter.get(
  '/users',
  asyncH(async (req, res) => {
    const { page, pageSize, skip, take } = pageParams(req);
    const q = String(req.query.q || '').trim();
    const where = q
      ? { OR: [{ nickname: { contains: q } }, { phone: { contains: q } }, { email: { contains: q } }] }
      : {};

    const [total, users] = await Promise.all([
      prisma.user.count({ where }),
      prisma.user.findMany({
        where,
        orderBy: { createdAt: 'desc' },
        skip,
        take,
        select: {
          id: true,
          nickname: true,
          phone: true,
          email: true,
          isAdmin: true,
          createdAt: true,
          _count: { select: { parcels: true, memberships: true, ownedGroups: true } },
        },
      }),
    ]);
    res.json({ total, page, pageSize, users });
  })
);

// 编辑用户：改昵称 / 设为或取消管理员 / 重置密码
adminRouter.patch(
  '/users/:id',
  asyncH(async (req, res) => {
    const { nickname, isAdmin, password } = z
      .object({
        nickname: z.string().min(1).max(20).optional(),
        isAdmin: z.boolean().optional(),
        password: z.string().min(6).optional(),
      })
      .parse(req.body || {});

    const target = await prisma.user.findUnique({ where: { id: req.params.id } });
    if (!target) return res.status(404).json({ message: '用户不存在' });

    // 不允许取消最后一个管理员的权限，避免无人能进后台
    if (isAdmin === false && target.isAdmin) {
      const adminCount = await prisma.user.count({ where: { isAdmin: true } });
      if (adminCount <= 1) return res.status(400).json({ message: '不能取消最后一个管理员的权限' });
    }

    const data = {};
    if (nickname !== undefined) data.nickname = nickname;
    if (isAdmin !== undefined) data.isAdmin = isAdmin;
    if (password !== undefined) data.passwordHash = await bcrypt.hash(password, 10);

    const user = await prisma.user.update({
      where: { id: req.params.id },
      data,
      select: { id: true, nickname: true, phone: true, email: true, isAdmin: true },
    });
    res.json({ user });
  })
);

// 删除用户（连带其名下群组、快递、群成员关系等一并清理）
adminRouter.delete(
  '/users/:id',
  asyncH(async (req, res) => {
    const id = req.params.id;
    if (id === req.user.id) return res.status(400).json({ message: '不能删除自己' });

    const target = await prisma.user.findUnique({ where: { id } });
    if (!target) return res.status(404).json({ message: '用户不存在' });

    if (target.isAdmin) {
      const adminCount = await prisma.user.count({ where: { isAdmin: true } });
      if (adminCount <= 1) return res.status(400).json({ message: '不能删除最后一个管理员' });
    }

    // 先删 TA 名下的群（群主关系无级联），再删用户（其余关系级联清理）
    await prisma.$transaction(async (tx) => {
      await tx.group.deleteMany({ where: { ownerId: id } });
      await tx.user.delete({ where: { id } });
    });
    res.json({ ok: true });
  })
);

// ==================== 群组管理 ====================

// 群组列表（分页 + 按群名/邀请码搜索）
adminRouter.get(
  '/groups',
  asyncH(async (req, res) => {
    const { page, pageSize, skip, take } = pageParams(req);
    const q = String(req.query.q || '').trim();
    const where = q ? { OR: [{ name: { contains: q } }, { inviteCode: { contains: q } }] } : {};

    const [total, groups] = await Promise.all([
      prisma.group.count({ where }),
      prisma.group.findMany({
        where,
        orderBy: { createdAt: 'desc' },
        skip,
        take,
        include: {
          owner: { select: { id: true, nickname: true, phone: true, email: true } },
          _count: { select: { members: true, sharedParcels: true } },
        },
      }),
    ]);
    res.json({ total, page, pageSize, groups });
  })
);

// 群组详情：成员 + 群内共享快递
adminRouter.get(
  '/groups/:id',
  asyncH(async (req, res) => {
    const group = await prisma.group.findUnique({
      where: { id: req.params.id },
      include: {
        owner: { select: { id: true, nickname: true } },
        members: {
          include: { user: { select: { id: true, nickname: true, phone: true, email: true } } },
          orderBy: { joinedAt: 'asc' },
        },
        sharedParcels: {
          include: {
            parcel: { select: { pickupCode: true, company: true, location: true } },
            sharedBy: { select: { nickname: true } },
          },
          orderBy: { createdAt: 'desc' },
        },
      },
    });
    if (!group) return res.status(404).json({ message: '群组不存在' });
    res.json({ group });
  })
);

// 删除群组（成员/申请/共享记录级联清理）
adminRouter.delete(
  '/groups/:id',
  asyncH(async (req, res) => {
    const group = await prisma.group.findUnique({ where: { id: req.params.id } });
    if (!group) return res.status(404).json({ message: '群组不存在' });
    await prisma.group.delete({ where: { id: req.params.id } });
    res.json({ ok: true });
  })
);

// 移除群成员（群主需整组删除，不能单独移除）
adminRouter.delete(
  '/groups/:groupId/members/:userId',
  asyncH(async (req, res) => {
    const { groupId, userId } = req.params;
    const group = await prisma.group.findUnique({ where: { id: groupId } });
    if (!group) return res.status(404).json({ message: '群组不存在' });
    if (group.ownerId === userId)
      return res.status(400).json({ message: '不能移除群主，请直接删除整个群组' });

    await prisma.groupMember.deleteMany({ where: { groupId, userId } });
    res.json({ ok: true });
  })
);

// ==================== 快递管理 ====================

// 查看所有取件码（分页 + 按状态筛选 + 搜索取件码/公司/位置）
adminRouter.get(
  '/parcels',
  asyncH(async (req, res) => {
    const { page, pageSize, skip, take } = pageParams(req);
    const q = String(req.query.q || '').trim();
    const where = {
      ...(req.query.status ? { status: String(req.query.status) } : {}),
      ...(q
        ? { OR: [{ pickupCode: { contains: q } }, { company: { contains: q } }, { location: { contains: q } }] }
        : {}),
    };

    const [total, parcels] = await Promise.all([
      prisma.parcel.count({ where }),
      prisma.parcel.findMany({
        where,
        include: { user: { select: { id: true, nickname: true, phone: true, email: true } } },
        orderBy: { createdAt: 'desc' },
        skip,
        take,
      }),
    ]);
    res.json({ total, page, pageSize, parcels });
  })
);

// 修改快递状态
adminRouter.patch(
  '/parcels/:id',
  asyncH(async (req, res) => {
    const { status } = z
      .object({ status: z.enum(['pending', 'picked', 'expired']) })
      .parse(req.body || {});
    const existing = await prisma.parcel.findUnique({ where: { id: req.params.id } });
    if (!existing) return res.status(404).json({ message: '快递不存在' });

    const parcel = await prisma.parcel.update({ where: { id: req.params.id }, data: { status } });
    res.json({ parcel });
  })
);

// 删除快递（共享记录级联清理）
adminRouter.delete(
  '/parcels/:id',
  asyncH(async (req, res) => {
    const existing = await prisma.parcel.findUnique({ where: { id: req.params.id } });
    if (!existing) return res.status(404).json({ message: '快递不存在' });
    await prisma.parcel.delete({ where: { id: req.params.id } });
    res.json({ ok: true });
  })
);

// ==================== 一键提醒 ====================

// 针对群内仍待取件的共享快递，提醒群里【除共享者以外】的成员去取
adminRouter.post(
  '/remind-all',
  asyncH(async (req, res) => {
    const { title, body } = z
      .object({ title: z.string().optional(), body: z.string().optional() })
      .parse(req.body || {});

    const shares = await prisma.sharedParcel.findMany({
      where: { status: 'pending' },
      include: { parcel: true },
    });

    await Promise.all(
      shares.map((s) =>
        notifyGroupMembers(s.groupId, s.sharedById, {
          type: 'admin_remind',
          title: title || '取件提醒',
          body: body || `取件码 ${s.parcel.pickupCode} 还没取，请尽快取件～`,
          data: { groupId: s.groupId, sharedId: s.id, parcelId: s.parcelId },
        })
      )
    );
    res.json({ ok: true, notified: shares.length });
  })
);

// ==================== 广播通知 ====================

// 手动向【全部用户】推送一条通知。每个用户都会落库一条，
// App 端轮询/前台服务即可收到；若配置了 FCM 也会真实推送。
adminRouter.post(
  '/broadcast',
  asyncH(async (req, res) => {
    const { title, body } = z
      .object({ title: z.string().min(1, '标题不能为空'), body: z.string().nullish() })
      .parse(req.body || {});

    const users = await prisma.user.findMany({ select: { id: true } });
    await Promise.all(
      users.map((u) =>
        createNotification(u.id, {
          type: 'admin_broadcast',
          title,
          body: body || null,
        })
      )
    );
    res.json({ ok: true, notified: users.length });
  })
);
