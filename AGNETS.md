# 拾序文件管理器（shixu-file-manager）

## 项目视图

面向 HarmonyOS 移动端的智能文件分类整理应用。核心使用方式为"先收纳，再按规则归类"：文件导入后按文件名、类型、内容关键字、格式、大小与使用场景自动归入对应分类，规则无法明确判断时保留人工确认流程。

- **技术栈**：HarmonyOS / ArkTS / ArkUI，Hvigor 构建，目标 SDK `6.1.0(23)`，版本 `1.0.0`
- **模块结构**：单 `entry` 模块（HarmonyOS Entry），无独立 HAR 模块
- **应用标识**：`AppScope/app.json5` 中的 bundleName 仍为占位值 `com.example.myapplication`，正式发布前需替换

### 代码组织（entry/src/main/ets/）

| 路径                                                  | 职责                                                                                                                 |
| ----------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------- |
| `pages/Index.ets`                                     | 主页面，包含全部 UI 与业务逻辑（导入、规则、分类、提取、确认），约 3000 行，后续按需拆分                             |
| `entryability/EntryAbility.ets`                       | 应用入口；接收系统分享文件（`want.uri` / `ability.params.stream`），写入 AppStorage `pendingSharedUris` 供主页面消费 |
| `formability/FileBoxFormAbility.ets`                  | 卡片 ExtensionAbility，注册两类表单                                                                                  |
| `recentfiles/pages/RecentFilesWidgetCard.ets`         | "最近文件"桌面卡片（2×2）                                                                                            |
| `quickcategories/pages/QuickCategoriesWidgetCard.ets` | "快捷分类"桌面卡片（2×2）                                                                                            |

### 数据与存储

- 使用 `@ohos.data.preferences` 持久化分类、规则、profile 配置与文件元数据（`Index.ets` 内 `persistState()` 负责）
- 文件导入经 `@ohos.file.picker` 选择，授权后复制到应用沙箱工作目录再解析
- 内容提取按格式分派：纯文本直接读取、图片走 `@ohos.ai` 文本识别（CoreVisionKit `textRecognition`）、Office 与 PDF 走 PDFKit 解析；提取结果存于 `FileItem.contentText` 供规则匹配

### Native / C++

- `entry/src/main/cpp/` 为 NAPI 骨架（`napi_init.cpp` 仅导出 `add` 示例），尚未接入业务
- 鸿蒙使用 musl C 库，后续 C++ 提升性能时注意编译默认链接问题（静态链接 musl 或随包分发兼容动态库）

### 测试

- `entry/src/test/`：本地单元测试（hypium）
- `entry/src/ohosTest/`：设备/模拟器测试
- `test-fixtures/`：规则与分类测试用的样例文件（按场景分目录：inbox/photographer/programmer/student）
- 测试数据只在 `test-fixtures/` 中维护，不要将个人真实文件放入仓库

## Git 规范

### 分支

- `main`：稳定主干，始终可构建可运行
- `feature/<主题>`：功能开发，如 `feature/RAG-LLM`
- `bugfix/<主题>`：缺陷修复
- `docs/<主题>`：文档类改动
- 功能分支完成后合入 `main`，合入前确保基于最新 `main` 并已自测

### 提交

- 提交信息用英文，简短描述实际变更（沿用仓库现有风格），推荐 `<type>: <summary>` 前缀：
  - `feat:` 新功能　`fix:` 缺陷修复　`refactor:` 重构　`docs:` 文档　`test:` 测试　`chore:` 构建/工具/杂项
- 一个提交对应一个逻辑变更，不要把无关改动混在一起
- 提交前 `git diff` 审查，排除无关改动与临时文件
- 提交粒度：完成一个可独立构建的阶段性变更即提交，避免大而全的巨型提交

### 禁止提交

- 构建产物与缓存：`oh_modules/`、`node_modules/`、`**/build`、`.hvigor/`、`.cxx`、`.idea/`、`local.properties`（已在 `.gitignore`）
- 密钥、token、账号信息等敏感内容
- 个人本地创意笔记（如 `创意说明.md`，已 ignore）
- 大体积演示截图：如需入库放根目录 `*.jpeg` 并明确用途，能不入库则不入库

### 协作

- 远端：`origin` = `git@github.com:SilentHydrogen/shixu-file-manager.git`
- 推送前先 `git fetch` 并确认基于最新 `main`
- 仓库已有 `feature/RAG-LLM`、`codex-project-updates` 分支，改动前确认目标分支，避免误提交到错误分支

## 静态资源放置路径

HarmonyOS 资源统一按官方 resource 目录组织，通过 `$media:xxx`、`$string:xxx`、`$color:xxx` 等符号引用，禁止在代码中硬编码资源路径。

| 资源类型                                            | 放置路径                                            | 引用方式         |
| --------------------------------------------------- | --------------------------------------------------- | ---------------- |
| 应用级图标（icon/foreground/background）            | `AppScope/resources/base/media/`                    | `$media:icon` 等 |
| 颜色                                                | `entry/src/main/resources/base/element/color.json`  | `$color:xxx`     |
| 字符串（含卡片 displayName/desc）                   | `entry/src/main/resources/base/element/string.json` | `$string:xxx`    |
| 浮点/尺寸                                           | `entry/src/main/resources/base/element/float.json`  | `$float:xxx`     |
| 图片、图标、音频等二进制资源                        | `entry/src/main/resources/base/media/`              | `$media:xxx`     |
| 页面与卡片配置（main_pages.json、form_config.json） | `entry/src/main/resources/base/profile/`            | `$profile:xxx`   |
| 需原样读取的文件（如规则词典）                      | `entry/src/main/resources/rawfile/`（目前未使用）   | `rawfile` API    |

约束：

- 新增图片一律放 `media/`，用语义化英文命名（如 `startIcon.png`），不用中文名或时间戳名
- 新增颜色、文案、尺寸先查 `element/` 现有条目，能复用不新增
- 按分辨率/密度需要分目录时，按官方规范建 `media-xxhdpi/` 等限定符目录，避免随意建目录
- 演示截图放项目根目录 `*.jpeg`（README 引用），不放 `resources/`；测试样例文件放 `test-fixtures/`

## 环境

- 开发工具：DevEco Studio / `devecocli`（Linux 下 build/run 需 `DEVECO_CLI_CLT_PATH` 指向 Command Line Tools）
- 构建：hvigor；依赖：ohpm；包配置见 `oh-package.json5`、`build-profile.json5`
- 文件管理器 skill 已安装于 `.agents/skills/deveco-cli`，可查文档、UI 检查、取日志等
