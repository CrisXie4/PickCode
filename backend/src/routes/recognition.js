import { Router } from 'express';
import { z } from 'zod';
import { authRequired } from '../middleware/auth.js';
import { asyncH } from '../middleware/error.js';
import { parseExpressText } from '../utils/parser.js';

export const recognitionRouter = Router();
recognitionRouter.use(authRequired);

// 智能识别：传入文本，返回解析结果（不落库，等用户确认后再调 /parcels 保存）
// OCR：客户端用本地 OCR（如 google_mlkit_text_recognition）把截图转文本后传 text 即可。
recognitionRouter.post(
  '/parse',
  asyncH(async (req, res) => {
    const { text } = z.object({ text: z.string().min(1) }).parse(req.body);
    const parsed = parseExpressText(text);
    res.json({ parsed });
  })
);
