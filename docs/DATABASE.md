# 数据库设计

ORM：Prisma。默认 SQLite，生产可无缝切 PostgreSQL（仅改 datasource provider）。
完整定义见 `backend/prisma/schema.prisma`。

## ER 关系
```
User 1───* Parcel
User 1───* Group (owner)
User *───* Group  (经 GroupMember 多对多)
Group 1──* JoinRequest *──1 User
Parcel 1─* SharedParcel *─1 Group   (一条快递可共享到多个群)
User 1───* Notification
```

## 表结构

### User 用户
| 字段 | 类型 | 说明 |
|------|------|------|
| id | String(cuid) | 唯一 ID（主键） |
| phone | String? unique | 手机号 |
| email | String? unique | 邮箱 |
| passwordHash | String | bcrypt 密码哈希 |
| nickname | String | 昵称 |
| avatarUrl | String? | 头像 |
| isAdmin | Boolean | 管理后台权限 |
| createdAt/updatedAt | DateTime | 时间戳 |

### Parcel 快递（个人私有）
`id, userId(FK), company?, pickupCode, locker?, location?, recipient?, note?, status, source, createdAt`
- status: `pending`待取件 / `picked`已取件 / `expired`已过期
- source: `manual / sms / clipboard / ocr`
- 索引：`userId`

### Group 群组
`id, name, ownerId(FK), inviteCode(unique), createdAt`

### GroupMember 群成员
`id, groupId(FK), userId(FK), role(owner/member), notifyEnabled, joinedAt`
- 唯一约束：`(groupId, userId)`

### JoinRequest 加群申请
`id, groupId(FK), userId(FK), status(pending/approved/rejected), message?, createdAt`
- 唯一约束：`(groupId, userId)`

### SharedParcel 群内共享快递
`id, parcelId(FK), groupId(FK), sharedById(FK), note?, status, createdAt`
- 唯一约束：`(parcelId, groupId)` —— 同一快递在同一群只共享一条
- 索引：`groupId`

### Notification 通知
`id, userId(FK), type, title, body?, data?(JSON), read, createdAt`
- type: `new_parcel / group_share / join_request / join_result / admin_remind`
- 索引：`(userId, read)`

## 权限与安全模型
- **个人快递**：查询/修改一律带 `where userId = 当前用户`，他人无法访问。
- **群内共享**：进入群详情前校验 `GroupMember` 是否存在；非成员 403。
- **加群审核**：`JoinRequest` 默认 pending，仅群主可 approve 后才写入 `GroupMember`。
- **敏感信息**：`publicUser()` 仅返回安全字段，永不返回 `passwordHash`。
- **后端校验**：所有写操作在服务端二次校验归属与角色，不信任客户端。
