# 绘世

绘世是一个基于 Flutter 开发的 Android APK 客户端，用于 NovelAI 图片免费小图生成相关功能。

## APK

已构建 APK 可在仓库的 `release/app-release.apk` 中获取。

## 提示词辅助写手 · Danbooru 校准

LLM 抽屉的提示词助手在每次回复后会自动调用 [DanbooruSearch](https://huggingface.co/spaces/SAkizuki/DanbooruSearch) 引擎对正向提示词做一次校准：

- **标签标准化**：把 LLM 写的非标准词替换成 Danbooru 真实存在的标签，规避角色名/作品名幻觉
- **共现补充**：基于 NPMI 共现统计补充常一同出现的细节标签
- **元数据展示**：每个 tag 附带中文名、wiki 释义、热度，悬浮可见

校准默认走 ModelScope 创空间端点（国内直连），失败自动切换到 HuggingFace Space 备份端点。两个端点都是公共免费服务，无需 API Key。

设置项位于 LLM 抽屉齿轮 → "Danbooru 校准"：
- 启用/关闭校准
- 自定义 Base URL（可填自托管地址）

校准结果显示在 LLM 消息底部，与全局 NSFW 开关联动。

## 致谢 / Credits

本项目的 NovelAI 绘图接口适配基于/参考了 [tt-P607](https://github.com/tt-P607) 的相关项目：

- [novelai-gateway](https://github.com/tt-P607/novelai-gateway)
- [new-api](https://github.com/tt-P607/new-api)

感谢原作者提供 NovelAI 绘图转 New API 相关接口方案。本项目主要提供 Android APK 客户端封装与界面实现，接口相关能力与原始方案归原作者所有。

提示词辅助写手的 Danbooru 校准功能基于 [SuzumiyaAkizuki/DanbooruSearch](https://huggingface.co/spaces/SAkizuki/DanbooruSearch)（[GitHub](https://github.com/SuzumiyaAkizuki/ComfyUI-DanbooruSearcher) · [数据库管线](https://github.com/SuzumiyaAkizuki/danbooru-tag-pipeline)）提供的语义检索 API。
