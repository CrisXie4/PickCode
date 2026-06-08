// 初始化管理员账号
import bcrypt from 'bcryptjs';
import { PrismaClient } from '@prisma/client';
import { config } from '../src/config.js';

const prisma = new PrismaClient();

async function main() {
  // 管理员
  const passwordHash = await bcrypt.hash(config.adminPassword, 10);
  const admin = await prisma.user.upsert({
    where: { email: config.adminEmail },
    update: { isAdmin: true },
    create: {
      email: config.adminEmail,
      passwordHash,
      nickname: '管理员',
      isAdmin: true,
    },
  });
  console.log('✅ 管理员:', config.adminEmail, '/', config.adminPassword);
  console.log('🌱 seed 完成');
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
