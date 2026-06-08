import { Router } from 'express';
import { z } from 'zod';
import { customAlphabet } from 'nanoid';
import { prisma } from '../prisma.js';
import { authRequired } from '../middleware/auth.js';
import { asyncH } from '../middleware/error.js';
import { createNotification, notifyGroupMembers } from '../services/notify.js';

export const groupRouter = Router();
groupRouter.use(authRequired);

const genInvite = customAlphabet('ABCDEFGHJKLMNPQRSTUVWXYZ23456789', 8);

// 校验：是否群主
async function assertOwner(groupId, userId) {
  const group = await prisma.group.findUnique({ where: { id: groupId } });
  if (!group) return { error: { status: 404, message: '群组不存在' } };
  if (group.ownerId !== userId) return { error: { status: 403, message: '仅群主可操作' } };
  return { group };
}

// 我加入的群组列表
groupRouter.get(
  '/',
  asyncH(async (req, res) => {
    const memberships = await prisma.groupMember.findMany({
      where: { userId: req.user.id },
      include: { group: { include: { _count: { select: { members: true } } } } },
      orderBy: { joinedAt: 'desc' },
    });
    res.json({
      groups: memberships.map((m) => ({
        ...m.group,
        role: m.role,
        notifyEnabled: m.notifyEnabled,
        memberCount: m.group._count.members,
      })),
    });
  })
);

// 创建群组（创建者自动成为群主+成员）
groupRouter.post(
  '/',
  asyncH(async (req, res) => {
    const { name } = z.object({ name: z.string().min(1).max(30) }).parse(req.body);
    const group = await prisma.group.create({
      data: {
        name,
        ownerId: req.user.id,
        inviteCode: genInvite(),
        members: { create: { userId: req.user.id, role: 'owner' } },
      },
    });
    res.json({ group });
  })
);

// 群详情 + 成员 + 群内共享快递（需为成员）
groupRouter.get(
  '/:id',
  asyncH(async (req, res) => {
    const member = await prisma.groupMember.findUnique({
      where: { groupId_userId: { groupId: req.params.id, userId: req.user.id } },
    });
    if (!member) return res.status(403).json({ message: '你不是该群成员' });

    const group = await prisma.group.findUnique({
      where: { id: req.params.id },
      include: {
        members: { include: { user: { select: { id: true, nickname: true, avatarUrl: true } } } },
        sharedParcels: {
          include: {
            parcel: true,
            sharedBy: { select: { id: true, nickname: true, avatarUrl: true } },
          },
          orderBy: { createdAt: 'desc' },
        },
      },
    });
    res.json({ group, myRole: member.role, notifyEnabled: member.notifyEnabled });
  })
);

// 通过邀请码申请加入（需群主审核）
groupRouter.post(
  '/join',
  asyncH(async (req, res) => {
    const { inviteCode, message } = z
      // nullish：客户端未填留言时会传 message: null，需同时接受 null 和不传
      .object({ inviteCode: z.string().min(1), message: z.string().nullish() })
      .parse(req.body);

    const group = await prisma.group.findUnique({ where: { inviteCode } });
    if (!group) return res.status(404).json({ message: '邀请码无效' });

    const existing = await prisma.groupMember.findUnique({
      where: { groupId_userId: { groupId: group.id, userId: req.user.id } },
    });
    if (existing) return res.status(409).json({ message: '你已是群成员' });

    const request = await prisma.joinRequest.upsert({
      where: { groupId_userId: { groupId: group.id, userId: req.user.id } },
      update: { status: 'pending', message },
      create: { groupId: group.id, userId: req.user.id, message, status: 'pending' },
    });

    // 通知群主
    await createNotification(group.ownerId, {
      type: 'join_request',
      title: '新的加群申请',
      body: `${req.user.nickname} 申请加入「${group.name}」`,
      data: { groupId: group.id, requestId: request.id },
    });

    res.json({ request });
  })
);

// 群主查看待审申请
groupRouter.get(
  '/:id/requests',
  asyncH(async (req, res) => {
    const { error } = await assertOwner(req.params.id, req.user.id);
    if (error) return res.status(error.status).json({ message: error.message });

    const requests = await prisma.joinRequest.findMany({
      where: { groupId: req.params.id, status: 'pending' },
      include: { user: { select: { id: true, nickname: true, avatarUrl: true } } },
      orderBy: { createdAt: 'desc' },
    });
    res.json({ requests });
  })
);

// 群主审批申请（approve / reject）
groupRouter.post(
  '/:id/requests/:requestId',
  asyncH(async (req, res) => {
    const { action } = z.object({ action: z.enum(['approve', 'reject']) }).parse(req.body);
    const { group, error } = await assertOwner(req.params.id, req.user.id);
    if (error) return res.status(error.status).json({ message: error.message });

    const request = await prisma.joinRequest.findUnique({ where: { id: req.params.requestId } });
    if (!request || request.groupId !== group.id)
      return res.status(404).json({ message: '申请不存在' });

    if (action === 'approve') {
      await prisma.$transaction([
        prisma.groupMember.create({ data: { groupId: group.id, userId: request.userId } }),
        prisma.joinRequest.update({ where: { id: request.id }, data: { status: 'approved' } }),
      ]);
    } else {
      await prisma.joinRequest.update({ where: { id: request.id }, data: { status: 'rejected' } });
    }

    await createNotification(request.userId, {
      type: 'join_result',
      title: '加群申请结果',
      body: `你加入「${group.name}」的申请已${action === 'approve' ? '通过' : '被拒绝'}`,
      data: { groupId: group.id },
    });

    res.json({ ok: true });
  })
);

// 群主移除成员（不能移除自己）
groupRouter.delete(
  '/:id/members/:userId',
  asyncH(async (req, res) => {
    const { error } = await assertOwner(req.params.id, req.user.id);
    if (error) return res.status(error.status).json({ message: error.message });
    if (req.params.userId === req.user.id)
      return res.status(400).json({ message: '群主不能移除自己' });

    await prisma.groupMember.deleteMany({
      where: { groupId: req.params.id, userId: req.params.userId },
    });
    res.json({ ok: true });
  })
);

// 切换群通知开关（每个成员独立）
groupRouter.patch(
  '/:id/notify',
  asyncH(async (req, res) => {
    const { enabled } = z.object({ enabled: z.boolean() }).parse(req.body);
    await prisma.groupMember.update({
      where: { groupId_userId: { groupId: req.params.id, userId: req.user.id } },
      data: { notifyEnabled: enabled },
    });
    res.json({ ok: true });
  })
);

// 手动提醒：群成员对某条共享快递发提醒（任意成员可发）
// - 若发起人是共享者本人 → 广播给群里其他人“帮我取一下”
// - 否则 → 提醒共享者本人“该取件了”
groupRouter.post(
  '/:id/shared/:sharedId/remind',
  asyncH(async (req, res) => {
    const member = await prisma.groupMember.findUnique({
      where: { groupId_userId: { groupId: req.params.id, userId: req.user.id } },
    });
    if (!member) return res.status(403).json({ message: '你不是该群成员' });

    const shared = await prisma.sharedParcel.findUnique({
      where: { id: req.params.sharedId },
      include: { parcel: true },
    });
    if (!shared || shared.groupId !== req.params.id)
      return res.status(404).json({ message: '共享记录不存在' });

    const code = shared.parcel.pickupCode;
    const isSharer = shared.sharedById === req.user.id;

    if (isSharer) {
      // 共享者求助：广播给群里其他开启通知的成员
      await notifyGroupMembers(req.params.id, req.user.id, {
        type: 'manual_remind',
        title: '有人请你帮忙取件',
        body: `${req.user.nickname}：帮我顺手拿一下 取件码 ${code}`,
        data: { groupId: req.params.id, sharedId: shared.id },
      });
    } else {
      // 提醒共享者本人
      await createNotification(shared.sharedById, {
        type: 'manual_remind',
        title: '取件提醒',
        body: `${req.user.nickname} 提醒你：取件码 ${code} 该取啦`,
        data: { groupId: req.params.id, sharedId: shared.id },
      });
    }
    res.json({ ok: true });
  })
);

// 标记已取件：任意群成员取件后调用
// → 通知发起人（共享者）已被取走 → 立即清除该共享记录（不占空间）
// → 个人快递状态置为 picked（后台定时任务会自动清除）
groupRouter.post(
  '/:id/shared/:sharedId/picked',
  asyncH(async (req, res) => {
    const member = await prisma.groupMember.findUnique({
      where: { groupId_userId: { groupId: req.params.id, userId: req.user.id } },
    });
    if (!member) return res.status(403).json({ message: '你不是该群成员' });

    const shared = await prisma.sharedParcel.findUnique({
      where: { id: req.params.sharedId },
      include: { parcel: true },
    });
    if (!shared || shared.groupId !== req.params.id)
      return res.status(404).json({ message: '共享记录不存在' });

    // 通知发起人（取件人不是本人时才通知）
    if (shared.sharedById !== req.user.id) {
      await createNotification(shared.sharedById, {
        type: 'parcel_picked',
        title: '快递已被取走',
        body: `${req.user.nickname} 已帮你取走 ${shared.parcel.company || '快递'} 取件码 ${shared.parcel.pickupCode}`,
        data: { parcelId: shared.parcelId },
      });
    }

    await prisma.$transaction([
      // 个人快递置为已取件（后台任务稍后自动清除）
      prisma.parcel.update({ where: { id: shared.parcelId }, data: { status: 'picked' } }),
      // 立即从群里清除该共享记录
      prisma.sharedParcel.delete({ where: { id: shared.id } }),
    ]);

    res.json({ ok: true, cleared: true });
  })
);

// 更新群内共享快递状态（共享者本人或群主）
groupRouter.patch(
  '/:id/shared/:sharedId',
  asyncH(async (req, res) => {
    const { status } = z.object({ status: z.enum(['pending', 'picked', 'expired']) }).parse(req.body);
    const shared = await prisma.sharedParcel.findUnique({ where: { id: req.params.sharedId } });
    if (!shared || shared.groupId !== req.params.id)
      return res.status(404).json({ message: '共享记录不存在' });

    const group = await prisma.group.findUnique({ where: { id: req.params.id } });
    const isOwner = group.ownerId === req.user.id;
    if (shared.sharedById !== req.user.id && !isOwner)
      return res.status(403).json({ message: '无权限修改' });

    const updated = await prisma.sharedParcel.update({
      where: { id: shared.id },
      data: { status },
    });
    res.json({ shared: updated });
  })
);
