// 快递信息智能识别
// 输入一段文本（短信 / 剪贴板 / OCR 识别结果），输出结构化字段。
// 纯规则实现，零依赖、可离线。后续可替换/叠加 NLP 模型。

const COMPANY_MAP = [
  { name: '顺丰', kw: ['顺丰', 'SF', 'sf'] },
  { name: '中通', kw: ['中通', 'ZTO'] },
  { name: '圆通', kw: ['圆通', 'YTO'] },
  { name: '申通', kw: ['申通', 'STO'] },
  { name: '韵达', kw: ['韵达', 'YUNDA'] },
  { name: '京东', kw: ['京东', 'JD', '京东物流'] },
  { name: '邮政', kw: ['邮政', 'EMS', '中国邮政'] },
  { name: '极兔', kw: ['极兔', 'J&T', 'JT'] },
  { name: '德邦', kw: ['德邦'] },
  { name: '菜鸟', kw: ['菜鸟', '菜鸟驿站'] },
];

const STATION_KW = ['驿站', '菜鸟', '快递柜', '丰巢', '取件柜', '代收点', '便利店', '超市', '小卖部'];

// 取件码：匹配 “取件码/凭xxx取件/编号” 后的字母数字组合（含 8-2-301 这类）
function extractPickupCode(text) {
  const patterns = [
    /取件码[:：\s]*([A-Za-z0-9\-]{3,20})/,
    /凭[:：\s]*([A-Za-z0-9\-]{3,20})[\s]*(?:取件|提货)/,
    /提货码[:：\s]*([A-Za-z0-9\-]{3,20})/,
    /验证码[:：\s]*([A-Za-z0-9\-]{3,20})/,
    /编号[:：\s]*([A-Za-z0-9\-]{3,20})/,
  ];
  for (const p of patterns) {
    const m = text.match(p);
    if (m) return m[1];
  }
  // 兜底：形如 12-3-08 / 8-2-301 的柜格码
  const fallback = text.match(/\b(\d{1,3}-\d{1,3}-\d{1,4})\b/);
  return fallback ? fallback[1] : null;
}

// 取件柜 / 柜格号
function extractLocker(text) {
  const patterns = [
    /([A-Za-z0-9]+号柜)/,
    /([A-Za-z0-9]{1,4}柜)/, // 丰巢/快递柜常见：B柜、A柜、12柜（字母/数字在前）
    /柜[:：\s]*([A-Za-z0-9\-]{1,12})/, // 柜:A12（编号在后）
    /(\d{1,3}-\d{1,3}-\d{1,4})/, // 柜-列-格
    /([A-Za-z]\d{1,3}格)/,
  ];
  for (const p of patterns) {
    const m = text.match(p);
    if (m) return m[1];
  }
  return null;
}

// 地址标签 & 字段终止词（用于切出“标签后整段”）
const ADDR_LABELS = '取件地址|取货地址|取件地点|自提地址|取件点|取货点|地址';
const STOP_LABELS =
  '配送人员|配送员|快递员|联系电话|联系方式|电话|手机|计费规则|计费|运单号|快递单号|单号|备注|温馨提示|快件|快递公司|时间';

// 去掉首尾的标点 / 连接符
function tidy(s) {
  return String(s)
    .replace(/^[\s：:，,。.、\-]+/, '')
    .replace(/[\s，,。.、；;！!]+$/, '')
    .trim();
}

// 清洗位置：若含“到/至/在/址/放/存”等连接词，取最后一个之后的部分
// 如“您的快递已到阳光小区”→“阳光小区”、“至东深小区”→“东深小区”
function cleanLocation(s) {
  const m = s.match(/.*[到至在址放存](.+)$/);
  return m ? m[1] : s;
}

// 位置 / 取件地址：尽量抓“完整地址”，而不是只抓小区名
function extractLocation(text) {
  // 1) 有明确“取件地址：”等标签 → 取标签后整段（到下一个字段标签或句末为止）
  const labeled = text.match(
    new RegExp(`(?:${ADDR_LABELS})[:：\\s]*(.+?)(?=\\s*(?:${STOP_LABELS})[:：]|[。；;]|$)`)
  );
  if (labeled && tidy(labeled[1])) return tidy(labeled[1]);

  // 2) 短信内联：“至/到/在 …… 取件/自提”之间整段（如：至东深小区B柜休闲广场旁B柜丰巢速递易柜取件）
  const inline = text.match(
    /[至到在]([一-龥A-Za-z0-9（）()·\-]{2,40}?)(?:取件|取货|提货|领取|自提)/
  );
  if (inline && tidy(inline[1])) return tidy(inline[1]);

  // 3) 小区/楼栋/广场 + 紧随的方位/柜号描述（如：东深小区休闲小广场旁丰巢柜1号）
  const community = text.match(
    /([一-龥]{2,12}(?:小区|花园|公寓|大厦|广场|社区|苑|村|庄|栋|楼|号院))((?:[一-龥A-Za-z0-9]|旁|号|柜|栋|幢|单元|室){0,30})/
  );
  if (community) return tidy(cleanLocation(community[1] + (community[2] || '')));

  // 4) 退而匹配 “xx驿站 / xx菜鸟 / xx快递柜”等代收点
  for (const kw of STATION_KW) {
    const re = new RegExp(`([\\u4e00-\\u9fa5A-Za-z0-9]{1,20}${kw}[\\u4e00-\\u9fa5A-Za-z0-9号]{0,10})`);
    const m = text.match(re);
    if (m) return tidy(cleanLocation(m[1]));
  }
  return null;
}

function extractCompany(text) {
  for (const c of COMPANY_MAP) {
    if (c.kw.some((k) => text.includes(k))) return c.name;
  }
  return null;
}

/**
 * 解析快递文本
 * @param {string} text 原始文本
 * @returns {{company,pickupCode,locker,location,raw,confidence}}
 */
export function parseExpressText(text = '') {
  const clean = String(text).replace(/\s+/g, ' ').trim();
  const result = {
    company: extractCompany(clean),
    pickupCode: extractPickupCode(clean),
    locker: extractLocker(clean),
    location: extractLocation(clean),
    raw: clean,
  };
  // 置信度：识别到的字段越多越高
  const hit = ['company', 'pickupCode', 'locker', 'location'].filter((k) => result[k]).length;
  result.confidence = Number((hit / 4).toFixed(2));
  return result;
}
