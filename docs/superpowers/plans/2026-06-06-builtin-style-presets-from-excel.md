# Built-in Style Presets from Excel Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将 `C:/Users/Elysia/Desktop/画师串.xlsx` 内的画风画师串和图片内置进 app，并在画风收藏为空时自动导入。

**Architecture:** 用 Python 脚本解析 xlsx 的 sharedStrings、worksheet 和 media 图片，生成 `assets/style_presets/style_presets.json` 与压缩图片。Flutter 侧在 `StylePresetRepositoryImpl.getAll()` 中检测本地表为空时读取 asset JSON 并插入 SQLite。

**Tech Stack:** Flutter/Dart, sqflite, rootBundle assets, Python stdlib zip/xml, image package.

---

## Files

- Create: `assets/style_presets/style_presets.json`
- Create: `assets/style_presets/*.jpg`
- Modify: `pubspec.yaml`
- Modify: `lib/data/repositories/style_preset_repository_impl.dart`

## Task 1: Extract Excel rows and images

- [ ] Use Python stdlib to parse `C:/Users/Elysia/Desktop/画师串.xlsx`.
- [ ] Read `xl/sharedStrings.xml` and `xl/worksheets/sheet1.xml`.
- [ ] Use column A as title, column B as prompt, column C `DISPIMG("ID",1)` as image id.
- [ ] Extract embedded images from `xl/media/` in row order.
- [ ] Create `assets/style_presets/style_presets.json` with objects `{ "title", "prompt", "assetImage" }`.
- [ ] Create compressed jpg images under `assets/style_presets/`.

## Task 2: Add asset registration

- [ ] Add `assets/style_presets/` to `pubspec.yaml` assets.

## Task 3: Auto-seed style presets

- [ ] In `StylePresetRepositoryImpl.getAll()`, if the SQLite table is empty, call `_seedBuiltinPresets()`.
- [ ] `_seedBuiltinPresets()` reads `assets/style_presets/style_presets.json`.
- [ ] Copy each asset image into app documents `style_presets` directory.
- [ ] Insert each preset into SQLite.
- [ ] Re-query and return seeded presets.

## Task 4: Verify and build

- [ ] Run `flutter analyze`.
- [ ] Sync `lib`, `assets`, and `pubspec.yaml` to `C:/Users/Elysia/nai_huishi_build`.
- [ ] Run `flutter clean && flutter build apk --release` in the non-Chinese build path.
- [ ] Copy APK to `C:/Users/Elysia/Desktop/绘世/app-release.apk`.

## Self-Review

- Covers Excel parsing, asset registration, first-load seeding, and APK output.
- No placeholders.
- Uses existing `StylePreset` data model and repository.
