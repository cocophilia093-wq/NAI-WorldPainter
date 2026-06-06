---
title: 提示词助手结构化替换与更多页 Danbooru 查词设计
date: 2026-06-06
---

# 提示词助手结构化替换与更多页 Danbooru 查词设计

## 目标

1. 修复提示词辅助助手“一键替换”依赖 LLM 排版的问题。
2. 将“设置”入口改名为“更多”，图标保持不变。
3. 在更多功能里新增 Danbooru 查词页面，直接调用 Danbooru API，不调用 LLM。
4. App 启动后默认进入生成页，避免先进入历史页。

## 一键替换解析

现有每个代码块上的手动按钮继续保留，作为精确人工控制入口。

新增结构化聚合解析：

- 优先解析助手回复中的 JSON 代码块或裸 JSON。
- 支持字段：
  - `positive`: 全局正向提示词。
  - `negative`: 全局负向提示词。
  - `characters`: 角色数组，每项支持 `positive` 和 `negative`。
- JSON 字段缺失时不报错，只使用可解析字段。
- JSON 不存在、解析失败或没有有效字段时，回退到现有“标题标签 + 代码块”的解析。
- “一键替换”只使用聚合成功的字段；单代码块按钮仍允许追加/替换正向或负向。

## 提示词约束

更新内置提示词，要求 LLM 优先输出一个 `json` 代码块。普通解释可以保留在 JSON 外，但可应用提示词内容必须放入 JSON 字段中。

推荐输出形态：

```json
{
  "positive": "masterpiece, best quality",
  "negative": "low quality, bad anatomy",
  "characters": [
    {
      "positive": "1girl, pink hair",
      "negative": "extra fingers"
    }
  ]
}
```

## 更多页

- `HomePage` 底部导航第 3 项文案从“设置”改为“更多”。
- `SettingsPage` 页面标题从“设置”改为“更多”。
- 图标保持 `CupertinoIcons.settings` / `settings_solid` 不变。
- API 配置入口保留在更多页中。

## Danbooru 查词页面

在更多功能组中新增“Danbooru 查词”入口。

页面行为：

- 用户输入关键词。
- 点击搜索后直接调用 `DanbooruApiService.search`。
- 不调用 LLM，不依赖提示词助手配置。
- 不提供 NSFW 开关，使用固定查询策略。
- 结果展示：tag、中文名、分类、热度、NSFW、wiki 摘要。
- 每个结果支持复制 NovelAI 风格 tag，即把 Danbooru 下划线 tag 转为空格 tag。
- 请求失败时展示错误信息，空结果时展示空状态。

## 首页调整

`HomePage` 默认 index 从历史页改为生成页：

- 初始 `_currentIndex = 1`。
- `IndexedStack` 页面顺序不变。
- 底部导航逻辑保持不变；生成页本身仍使用现有生成页布局。

## 测试与验证

- 增加或调整提示词聚合解析测试，覆盖：
  - JSON 代码块。
  - 裸 JSON。
  - 多角色正负向。
  - 缺字段。
  - 非 JSON 时回退旧代码块标签解析。
- 运行 Flutter 静态检查和测试。
- 构建 APK 后按项目约定复制到 `C:\Users\Elysia\Desktop\绘世`。

## 自检

- 无 TBD/TODO。
- 结构化解析与手动按钮并存，不冲突。
- Danbooru 查词明确不调用 LLM。
- “更多”只改名称，不改图标。
- 默认首页改为生成页，范围明确。
