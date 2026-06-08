import { Router } from 'express';
import { z } from 'zod';
import { prisma } from '../prisma.js';
import { authRequired } from '../middleware/auth.js';
import { asyncH } from '../middleware/error.js';
import { createNotification, notifyGroupMembers } from '../services/notify.js';

export const parcelRouter = Router();
parcelRouter.use(authRequired);

// nullish：客户端对未填写的可选字段会传 null，需同时接受 null 和不传
const parcelSchema = z.object({
  company: z.string().nullish(),
  pickupCode: z.string().min(1),
  locker: z.string().nullish(),
  location: z.string().nullish(),
  recipient: z.string().nullish(),
  note: z.string().nullish(),
  status: z.enum(['pending', 'picked', 'expired']).optional(),
  source: z.enum(['manual', 'sms', 'clipboard', 'ocr']).optional(),
});

// 我的快递列表
parcelRouter.get(
  '/',
  asyncH(async (req, res) => {
    const parcels = await prisma.parcel.findMany({
      where: { userId: req.user.id },
      orderBy: { createdAt: 'desc' },
    });
    res.json({ parcels });
  })
);

// 新增快递（识别确认后保存 / 手动添加）→ 触发“新取件码”通知
parcelRouter.post(
  '/',
  asyncH(async (req, res) => {
    const data = parcelSchema.parse(req.body);
    const parcel = await prisma.parcel.create({ data: { ...data, userId: req.user.id } });

    await createNotification(req.user.id, {
      type: 'new_parcel',
      title: '新的取件码',
      body: `${parcel.company || '快递'} 取件码 ${parcel.pickupCode}`,
      data: { parcelId: parcel.id },
    });

    res.json({ parcel });
  })
);

// 更新快递 / 改状态（仅本人）
parcelRouter.patch(
  '/:id',
  asyncH(async (req, res) => {
    const data = parcelSchema.partial().parse(req.body);
    const existing = await prisma.parcel.findUnique({ where: { id: req.params.id } });
    if (!existing || existing.userId !== req.user.id)
      return res.status(404).json({ message: '快递不存在或无权限' });

    const parcel = await prisma.parcel.update({ where: { id: req.params.id }, data });
    res.json({ parcel });
  })
);

// 删除快递（仅本人）
parcelRouter.delete(
  '/:id',
  asyncH(async (req, res) => {
    const existing = await prisma.parcel.findUnique({ where: { id: req.params.id } });
    if (!existing || existing.userId !== req.user.id)
      return res.status(404).json({ message: '快递不存在或无权限' });
    await prisma.parcel.delete({ where: { id: req.params.id } });
    res.json({ ok: true });
  })
);

// 共享到群组 → 通知群成员
parcelRouter.post(
  '/:id/share',
  asyncH(async (req, res) => {
    const { groupId, note } = z.object({ groupId: z.string(), note: z.string().nullish() }).parse(req.body);

    const parcel = await prisma.parcel.findUnique({ where: { id: req.params.id } });
    if (!parcel || parcel.userId !== req.user.id)
      return res.status(404).json({ message: '快递不存在或无权限' });

    // 必须是群成员才能共享
    const member = await prisma.groupMember.findUnique({
      where: { groupId_userId: { groupId, userId: req.user.id } },
    });
    if (!member) return res.status(403).json({ message: '你不是该群成员' });

    const shared = await prisma.sharedParcel.upsert({
      where: { parcelId_groupId: { parcelId: parcel.id, groupId } },
      update: { note, status: parcel.status },
      create: { parcelId: parcel.id, groupId, sharedById: req.user.id, note, status: parcel.status },
    });

    await notifyGroupMembers(groupId, req.user.id, {
      type: 'group_share',
      title: '群内有新快递共享',
      body: `${req.user.nickname} 共享了 ${parcel.company || '快递'} 取件码 ${parcel.pickupCode}`,
      data: { groupId, sharedId: shared.id },
    });

    res.json({ shared });
  })
);

// 取消共享
parcelRouter.delete(
  '/:id/share/:groupId',
  asyncH(async (req, res) => {
    const parcel = await prisma.parcel.findUnique({ where: { id: req.params.id } });
    if (!parcel || parcel.userId !== req.user.id)
      return res.status(404).json({ message: '无权限' });
    await prisma.sharedParcel.deleteMany({
      where: { parcelId: req.params.id, groupId: req.params.groupId },
    });
    res.json({ ok: true });
  })
);
