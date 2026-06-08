import express from 'express';
import cors from 'cors';
import { config } from './config.js';
import { errorHandler } from './middleware/error.js';
import { authRouter } from './routes/auth.js';
import { userRouter } from './routes/users.js';
import { parcelRouter } from './routes/parcels.js';
import { groupRouter } from './routes/groups.js';
import { recognitionRouter } from './routes/recognition.js';
import { notificationRouter } from './routes/notifications.js';
import { adminRouter } from './routes/admin.js';
import { startCleanupJob } from './services/cleanup.js';
import { startReminderJob } from './services/reminder.js';

import path from 'path';
import { fileURLToPath } from 'url';
const __dirname = path.dirname(fileURLToPath(import.meta.url));

const app = express();
app.use(cors());
app.use(express.json({ limit: '2mb' }));

// 管理后台静态页面：访问 http://localhost:3000/admin/
app.use('/admin', express.static(path.join(__dirname, '../public')));

app.get('/', (req, res) => res.json({ name: 'Express Pickup API', status: 'ok' }));
app.get('/health', (req, res) => res.json({ ok: true }));

app.use('/api/auth', authRouter);
app.use('/api/users', userRouter);
app.use('/api/parcels', parcelRouter);
app.use('/api/groups', groupRouter);
app.use('/api/recognition', recognitionRouter);
app.use('/api/notifications', notificationRouter);
app.use('/api/admin', adminRouter);

app.use(errorHandler);

app.listen(config.port, () => {
  console.log(`🚀 API 已启动: http://localhost:${config.port}`);
  startCleanupJob(); // 启动自动清除任务
  startReminderJob(); // 启动自动催取任务（免费期内每 2 小时提醒群成员取件）
});
