/**
 * 三本法典 → nsfw_knowledge.json 提取脚本
 *
 * 提取策略：
 * 1. 用「? xxx」作为章节分割符
 * 2. 每个章节下的有内容行作为知识块候选
 * 3. 按行特征提取关键词：
 *   - 包含 char1：/ char2：的多角色行 → 体位块
 *   - 以 1girl, 1boy, 2girls 开头的行 → 体位/姿势块
 *   - 包含（本体）（服装）的行 → OC/角色块
 *   - 数字+逗号开头的行 → 画师组块
 *   - 其他带大量英文 tag 的长行 → 通用知识块
 * 4. 每个块自动生成关键词（从中英文混合内容中提取）
 */

const fs = require('fs');
const iconv = require('C:/Users/Elysia/Desktop/nai 绘世/node_modules/iconv-lite');

const BASE = 'C:/Users/Elysia/Downloads/焚决/';
const FILES = [
  {
    name: '所长常规NovelAI个人法典（2026.5.20版，一般所长整理）.txt',
    category: 'regular'
  },
  {
    name: '所长色色NovalAI个人法典（上）（2026.5.20版，一般所长整理）.txt',
    category: 'nsfw_upper'
  },
  {
    name: '所长色色NovalAI个人法典（下）（2026.5.20版，一般所长整理）.txt',
    category: 'nsfw_lower'
  }
];

const OUTPUT = 'C:/Users/Elysia/nai_huishi_build/lib/assets/nsfw_knowledge.json';
const OUTPUT_FINAL = 'C:/Users/Elysia/Desktop/nai 绘世/lib/assets/nsfw_knowledge.json';

// ===== 解析 =====

function loadTxt(filepath) {
  const raw = fs.readFileSync(filepath);
  return iconv.decode(raw, 'gbk');
}

/**
 * 从一行 tag 文本中提取关键词（中英文）
 */
function extractKeywords(line, chapterTitle) {
  const words = new Set();

  // 从中文字段提取关键词
  const cnMatches = line.match(/[\u4e00-\u9fff]{2,8}/g);
  if (cnMatches) {
    cnMatches.forEach(w => words.add(w));
  }

  // 从 chapter title 添加
  if (chapterTitle) {
    const cnChapter = chapterTitle.match(/[\u4e00-\u9fff]{2,8}/g);
    if (cnChapter) cnChapter.forEach(w => words.add(w));
  }

  // 从 tag 文本中提取有意义的英文关键词（排除太通用的）
  const tagMatches = line.match(/(?:^|[,，])\s*([a-zA-Z_][a-zA-Z_0-9]{1,30})/g);
  if (tagMatches) {
    tagMatches.forEach(t => {
      const clean = t.replace(/[,，\s]/g, '').toLowerCase();
      if (clean.length > 2 && !['nsfw','solo','focus','male','girl','boy','1girl','1boy','2girls','on','in','at','no','of'].includes(clean)) {
        words.add(clean);
      }
    });
  }

  // 从 char1：/ char2： 也提取
  const charMatches = line.match(/char\d+[：:]\s*([^,，]+)/g);
  if (charMatches) {
    charMatches.forEach(c => {
      const t = c.replace(/char\d+[：:]\s*/g, '').trim().toLowerCase();
      if (t.length > 2) words.add(t);
    });
  }

  return Array.from(words).slice(0, 15);
}

/**
 * 判断一行是否是有价值的 tag 行
 */
function isTagLine(line) {
  if (!line || line.length < 30) return false;
  // 跳过章节标记、前訁、目录
  if (line.startsWith('? ') || line.startsWith('目彔') || line.startsWith('─') || line.startsWith('PS') || line.startsWith('—')) return false;
  if (line.match(/^[\d，,、\s　]+$/)) return false;
  // 必须包含英文 tag 特征
  if (!line.includes(',') && !line.includes('::') && !line.includes('：')) return false;
  if (line.match(/^[\u4e00-\u9fff，。、；\s\d]+$/)) return false;
  return true;
}

function isArtistGroupLine(line) {
  return line.includes('artist:') && line.match(/^\d[，,]/);
}

function isMultiCharLine(line) {
  return line.startsWith('char') && (line.includes('：') || line.includes(':'));
}

function isOcLine(line) {
  return line.includes('（本体）') || line.includes('（服装）') || line.includes('（服装）');
}

function isPositionLine(line) {
  // 以 tag 开头的体位描述行
  return line.match(/^(1girl,|1boy,|2girls,|nsfw,|uncensored,|front view,|from )/);
}

// ===== 主逻辑 =====

let allEntries = [];
let entryId = 0;

for (const fileCfg of FILES) {
  const text = loadTxt(BASE + fileCfg.name);
  const lines = text.split('\n');

  let currentChapter = '';
  let chapterLineStart = -1;

  for (let i = 0; i < lines.length; i++) {
    const raw = lines[i];
    const trimmed = raw.trimEnd();
    const s = trimmed.trim();

    // 检测章节标记
    if (s.startsWith('? ')) {
      currentChapter = s.substring(2).trim();
      chapterLineStart = i;
      continue;
    }

    if (!isTagLine(s)) continue;

    // 确定知识块类型
    let blockType = 'generic';
    let title = '';
    let keywords = [];

    if (isArtistGroupLine(s)) {
      blockType = 'artist_group';
      title = currentChapter + ' - 画师组 ' + s.match(/^\d+/)?.[0] || '';
      const artistNames = s.match(/artist:([a-zA-Z_0-9()]+)/g) || [];
      keywords = extractKeywords(s, currentChapter);
      // 添加画师名
      artistNames.forEach(a => {
        const name = a.replace('artist:', '').toLowerCase();
        keywords.push(name);
      });
    }
    else if (isOcLine(s)) {
      blockType = 'oc';
      title = currentChapter + ' - OC设定';
      keywords = extractKeywords(s, currentChapter);
    }
    else if (isMultiCharLine(s)) {
      blockType = 'multi_char';
      // 看前几行找到体位描述
      let posLine = '';
      for (let j = i - 1; j >= Math.max(0, i - 5); j--) {
        const prev = lines[j].trim();
        if (isPositionLine(prev)) { posLine = prev; break; }
        if (prev.startsWith('char')) continue;
        if (prev.startsWith('? ')) break;
      }
      title = currentChapter + ' - 多角色配置';
      keywords = extractKeywords(s + ' ' + posLine, currentChapter);
    }
    else if (isPositionLine(s)) {
      blockType = 'pose';
      title = currentChapter + ' - 体位/姿势';
      keywords = extractKeywords(s, currentChapter);
    }
    else {
      // 通用 tag 块（如服饰、场景等）
      blockType = 'tag_set';
      title = currentChapter + ' - tag组合';
      keywords = extractKeywords(s, currentChapter);
    }

    // 去重关键词
    keywords = [...new Set(keywords)];

    // 过滤：如果关键词太少则跳过
    if (keywords.length < 2 && !isArtistGroupLine(s) && !isOcLine(s)) continue;

    // 规范化内容：去掉行号前缀
    let content = s.replace(/^\d+[，,]\s*/, '');

    // 收集前后关联行（用于体位等需要上下文的块）
    let contextLines = [];
    if (blockType === 'pose' || blockType === 'multi_char') {
      // 收接下来的 char 行
      for (let j = i + 1; j < Math.min(lines.length, i + 6); j++) {
        const next = lines[j].trim();
        if (next.startsWith('char') && (next.includes('：') || next.includes(':'))) {
          contextLines.push(next);
        } else if (next.startsWith('? ') || next.startsWith('1girl,') || next.startsWith('1boy,') || next.startsWith('2girls')) {
          break;
        }
      }
      if (contextLines.length > 0) {
        content = content + '\n' + contextLines.join('\n');
      }
    }

    // 关联的体位描述行（如果当前是 char 行，找前面的体位描述）
    if (blockType === 'multi_char') {
      for (let j = i - 1; j >= Math.max(0, i - 5); j--) {
        const prev = lines[j].trim();
        if (isPositionLine(prev)) {
          content = prev + '\n' + content;
          break;
        }
      }
    }

    entryId++;
    allEntries.push({
      id: entryId,
      title: title || currentChapter,
      type: blockType,
      category: fileCfg.category,
      keywords: keywords,
      content: content,
      lineNumber: i + 1
    });
  }

  console.log(`[${fileCfg.name}] 提取了 ${entryId} 条（当前累计）`);
}

// ===== 合并连续同类块（体位块经常分散为多行） =====

console.log(`\n总提取数: ${allEntries.length}`);

// ===== 生成源目录添加到每块 =====
const sourceNames = {
  'regular': '常规法典',
  'nsfw_upper': '色色上',
  'nsfw_lower': '色色下'
};

allEntries.forEach(e => {
  e.source = sourceNames[e.category] || e.category;
  delete e.category; // 不保留分类字段
  delete e.lineNumber; // 不保留行号
});

// ===== 输出 =====

const output = JSON.stringify(allEntries, null, 2);
fs.writeFileSync(OUTPUT, output, 'utf-8');
console.log(`\n输出到: ${OUTPUT}`);
console.log(`文件大小: ${(Buffer.byteLength(output) / 1024).toFixed(1)} KB`);

// 也输出一份到项目目录
try {
  fs.mkdirSync('C:/Users/Elysia/Desktop/nai 绘世/lib/assets', { recursive: true });
  fs.writeFileSync(OUTPUT_FINAL, output, 'utf-8');
  console.log(`同时输出到: ${OUTPUT_FINAL}`);
} catch(e) {
  console.log(`项目目录输出失败（可能不存在）: ${e.message}`);
}

// ===== 统计 =====
const typeCount = {};
allEntries.forEach(e => {
  typeCount[e.type] = (typeCount[e.type] || 0) + 1;
});
console.log('\n=== 块类型分布 ===');
Object.entries(typeCount).sort((a,b)=>b[1]-a[1]).forEach(([k,v]) => {
  console.log(`  ${k}: ${v}`);
});

console.log('\n=== 前 20 条示例 ===');
allEntries.slice(0, 20).forEach(e => {
  console.log(`[${e.type}] ${e.title}`);
  console.log(`  keywords: ${e.keywords.slice(0, 8).join(', ')}`);
  console.log(`  content: ${e.content.substring(0, 100)}...`);
  console.log();
});