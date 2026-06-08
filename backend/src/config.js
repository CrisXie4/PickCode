import dotenv from 'dotenv';
dotenv.config();

// 容错：去掉值里可能误带的引号和首尾空格，避免 jwt.sign 因 expiresIn 格式非法而 500。
// 例如 .env 里写成 `JWT_EXPIRES_IN="30d "`（带引号/尾空格）都能被纠正成 30d。
function clean(v) {
  if (v == null) return undefined;
  const s = String(v).trim().replace(/^["']|["']$/g, '').trim();
  return s.length ? s : undefined;
}

export const config = {
  port: clean(process.env.PORT) || 3000,
  jwtSecret: clean(process.env.JWT_SECRET) || 'dev-secret',
  jwtExpiresIn: clean(process.env.JWT_EXPIRES_IN) || '30d',
  adminEmail: clean(process.env.ADMIN_EMAIL) || 'admin@express.local',
  adminPassword: clean(process.env.ADMIN_PASSWORD) || 'admin123456',
};
