# API 接口设计

Base URL: `http://<host>:3000/api`
鉴权：除注册/登录外，所有接口需带 `Authorization: Bearer <token>`。

## 认证 Auth
| 方法 | 路径 | 说明 | Body |
|------|------|------|------|
| POST | `/auth/register` | 注册（无需验证码） | `{phone?, email?, password, nickname?}` |
| POST | `/auth/login` | 登录 | `{account, password}`（account=手机号或邮箱） |

返回：`{ token, user }`

## 用户 Users
| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/users/me` | 当前用户信息 |
| PATCH | `/users/me` | 修改昵称/头像 `{nickname?, avatarUrl?}` |

## 智能识别 Recognition
| 方法 | 路径 | 说明 |
|------|------|------|
| POST | `/recognition/parse` | 文本识别 `{text}` → `{parsed:{company,pickupCode,locker,location,confidence}}` |

> OCR 在客户端本地完成（截图→文本），再把文本传给此接口。

## 快递 Parcels
| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/parcels` | 我的快递列表 |
| POST | `/parcels` | 新增（触发"新取件码"通知） |
| PATCH | `/parcels/:id` | 更新/改状态（仅本人） |
| DELETE | `/parcels/:id` | 删除（仅本人） |
| POST | `/parcels/:id/share` | 共享到群组 `{groupId, note?}`（触发群通知） |
| DELETE | `/parcels/:id/share/:groupId` | 取消共享 |

快递字段：`company, pickupCode*, locker, location, recipient, note, status(pending/picked/expired), source(manual/sms/clipboard/ocr)`

## 群组 Groups
| 方法 | 路径 | 说明 | 权限 |
|------|------|------|------|
| GET | `/groups` | 我加入的群 | 成员 |
| POST | `/groups` | 创建群 `{name}` | 登录用户 |
| GET | `/groups/:id` | 群详情(成员+共享快递) | 群成员 |
| POST | `/groups/join` | 邀请码申请加群 `{inviteCode, message?}` | 登录用户 |
| GET | `/groups/:id/requests` | 待审申请列表 | 群主 |
| POST | `/groups/:id/requests/:reqId` | 审批 `{action:'approve'\|'reject'}` | 群主 |
| DELETE | `/groups/:id/members/:userId` | 移除成员 | 群主 |
| PATCH | `/groups/:id/notify` | 群通知开关 `{enabled}` | 成员 |
| POST | `/groups/:id/shared/:sharedId/remind` | 手动提醒 | 群成员 |
| POST | `/groups/:id/shared/:sharedId/picked` | 标记已取件(通知发起人+清除共享记录) | 群成员 |
| PATCH | `/groups/:id/shared/:sharedId` | 改共享状态 `{status}` | 共享者/群主 |

## 通知 Notifications
| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/notifications` | 通知列表 + 未读数 |
| POST | `/notifications/read` | 标记已读 `{id?}`（无 id 则全部已读） |

## 管理后台 Admin（需 isAdmin）
| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/admin/stats` | 概览统计 |
| GET | `/admin/parcels` | 所有取件码（分页 `?page&pageSize&status`） |
| POST | `/admin/remind-all` | 一键提醒所有待取件用户 `{title?, body?}` |

## 错误约定
- `400` 参数校验失败 · `401` 未登录/token 失效 · `403` 无权限 · `404` 资源不存在 · `409` 唯一冲突
- 统一格式：`{ message, ... }`
