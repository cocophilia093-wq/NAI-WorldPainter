# nai 绘世 - 前端对接文档

> 本文档供 Gemini 3.1 Pro 设计 UI 时参考。后端逻辑已写好，前端主要绑定 ViewModel。

## 文档位置

- `C:\Users\Elysia\Desktop\nai 绘世\FRONTEND_GUIDE.md`

## 已完成的可对接层

- 设置管理：API Key、Base URL、默认参数
- NovelAI 接口适配：`/v1/models`、`/v1/chat/completions`
- 本地 SQLite：历史、预设、Prompt 模板
- 本地图片保存
- 单并发生成队列
- 批量生成入队
- ViewModel 层
- ViewModel 已注册到 `lib/core/di/injection.dart`

## 前端主要对接文件

### 1. 生成页
- `lib/presentation/viewmodels/generation_viewmodel.dart`

核心字段：
- `prompt`
- `negativePrompt`
- `selectedModel`
- `selectedResolution`
- `selectedSampler`
- `scale`
- `cfgRescale`
- `selectedNoiseSchedule`
- `characters`
- `batchCount`
- `models`
- `isGenerating`
- `pendingCount`
- `lastCompletedTask`
- `errorMessage`

核心方法：
- `loadModels()`
- `generate()`
- `generateBatch()`
- `saveImage(task)`
- `addCharacter(prompt, centerX, centerY)`
- `removeCharacter(index)`
- `updateCharacter(index, char)`
- `loadFromPreset(preset)`
- `clearForm()`

说明：
- `loadFromPreset(...)` 现在接收 `Preset`，不是 `GenerationTask`
- 生成统一走 `GenerationQueue`，不要在 UI 层自行并发发图

### 2. 历史页
- `lib/presentation/viewmodels/history_viewmodel.dart`

核心方法：
- `loadHistory(refresh: true)`
- `loadHistory()`
- `loadFavorites()`
- `toggleFavorite(taskId)`
- `deleteTask(taskId)`

### 3. 预设页
- `lib/presentation/viewmodels/preset_viewmodel.dart`

核心方法：
- `loadPresets()`
- `initBuiltinPresets()`
- `filterByCategory(category)`
- `createPreset(preset)`
- `updatePreset(preset)`
- `deletePreset(id)`

### 4. Prompt 模板页
- `lib/presentation/viewmodels/prompt_template_viewmodel.dart`

核心方法：
- `loadTemplates()`
- `filterByCategory(category)`
- `search(query)`
- `createTemplate(template)`
- `updateTemplate(template)`
- `deleteTemplate(id)`
- `useTemplate(id)`

### 5. 设置页
- `lib/presentation/viewmodels/settings_viewmodel.dart`

核心方法：
- `loadSettings()`
- `setApiKey(key)`
- `deleteApiKey()`
- `setBaseUrl(url)`
- `setDefaultModel(model)`
- `setDefaultResolution(r)`
- `setDefaultSampler(s)`
- `setDefaultScale(v)`
- `setDefaultCfgRescale(v)`
- `setDefaultNoiseSchedule(s)`
- `testConnection()`

## 依赖注入

ViewModel 已经注册在 `lib/core/di/injection.dart`，前端可以直接取用：

```dart
import 'package:nai_huishi/core/di/injection.dart';

final generationVM = sl<GenerationViewModel>();
final historyVM = sl<HistoryViewModel>();
final presetVM = sl<PresetViewModel>();
final promptTemplateVM = sl<PromptTemplateViewModel>();
final settingsVM = sl<SettingsViewModel>();
```

## 前端初始化建议

启动后建议顺序：

1. `configureDependencies()`
2. `SettingsViewModel.loadSettings()`
3. `PresetViewModel.initBuiltinPresets()`
4. `GenerationViewModel.loadModels()`
5. `HistoryViewModel.loadHistory(refresh: true)`
6. `PromptTemplateViewModel.loadTemplates()`

## UI 页面建议

建议页面结构：

1. 首页 / 生成页
   - Prompt 输入
   - 负面词输入
   - 模型选择
   - 尺寸/采样器/Scale 参数
   - 多人物坐标编辑
   - 单张生成 / 批量生成
   - 最近结果预览

2. 历史页
   - 生成记录列表
   - 收藏/删除/保存到本地

3. 预设页
   - 内置预设
   - 自定义预设管理

4. Prompt 模板页
   - 分类筛选
   - 搜索
   - 模板插入

5. 设置页
   - API Key
   - Base URL
   - 连接测试
   - 默认参数

## 注意事项

- 上游只支持单并发，前端不要自己并发发图，统一走 `GenerationQueue`
- `chat/completions` 返回的图片通常是 Markdown 图片链接，后端已做解析
- 批量生成是“多任务排队”，不是并发生成
- 图片保存优先保存到应用本地目录
- 当前主流程优先支持 `chat/completions` 的图片 URL 返回
- `saveToGallery()` 还没接系统相册插件

## 当前状态

目前项目已经具备：

- 可继续交给 Gemini 做 UI
- 可在安装 Flutter SDK 后继续执行依赖安装与静态检查
- 可继续补剩余编译级小问题

## 最小联调方式

当前已经有最小前端壳子：

- `lib/presentation/pages/home_page.dart`
- `lib/presentation/pages/generate_page.dart`
- `lib/presentation/pages/history_page.dart`
- `lib/presentation/pages/settings_page.dart`

最小联调步骤：

1. 进入设置页
2. 填入你的 `API Key`
3. 填入你的 `Base URL`
4. 点击“测试连接”
5. 回到生成页输入 prompt
6. 点击“生成”
7. 在结果区预览图片
8. 点击“保存到应用目录”
9. 去历史页确认记录是否落库

## 建议下一步

1. 安装 Flutter SDK
2. 运行 `flutter pub get`
3. 运行 `flutter analyze`
4. 根据 analyzer 报错做最后一轮修补
5. 真机联调一轮
6. 把本文件喂给 Gemini 生成完整 UI

如果你要把这份文档直接发给 Gemini，可以直接把这个文件内容喂给它。