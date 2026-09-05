# Pi SDK 与后台文件分类验证（2026-09-05）

## 实现范围

- 后台和手动分类共用 FileOrganizeService；充电 OR 可配置时间窗，后台读取真实设备状态。
- 精确规则、LLM-RAG、本地 Embedding 以及人工确认共享分类应用接口；实际用户分类白名单、规则冲突、置信度、文件/规则变更校验。
- 本地作业记录、退避重试、90 秒后台预算、停止、手动接管后台。
- ohpm 下载/转换的官方 Pi Agent Core / pi-ai 0.73.1；官方 Responses / Chat Completions SSE 和工具循环。
- 智能分类页增加模式、批量/单文件触发、后台设置、停止和待确认结果。

## 自动验证

| 检查 | 结果 |
| --- | --- |
| devecocli build（含 SDK HAR 更换后的 clean build） | 通过，ArkTS / JS 编译与签名 HAP 生成成功；仍有项目既有废弃 API 等警告 |
| scripts/check-classification.cjs | 通过：正文规则、自定义分类、共同分类落库、模型不可用/未授权时本地处理、低分/冲突确认、旧建议拦截、持久作业、跨午夜及 OR 条件、手动接管后台 |
| scripts/check-pi-sdk.cjs | 通过：真实 SDK 的 Responses/Chat SSE、中文、工具循环与终止、分类 enum 校验、401 脱敏、HTTP 释放；加载前移除 Node/浏览器全局对象 |
| scripts/check-llm.cjs | 通过：HUKS 保存不重建密钥、INT32/INT64 输入 buffer、索引补充不擅自改类、建议去重、地址校验和网络错误提示 |
| 上游源码完整性 | 10 个锁定依赖的归档 SHA-512 与转换后 JavaScript 文件校验通过，SDK/provider 源码未改写 |
| git diff --check | 通过 |

测试使用模拟系统存储/HTTP 和测试数据，不将主机测试称为真机系统调度测试。全量 Hypium Linux runner 在前一轮工作中不能完成启动，本轮未宣称全量 Hypium 通过。

## 真机

设备：192.168.1.120:34157，nova 14。覆盖安装保留应用数据。

- 初次安装完成，但因锁屏无法启动（10106102）；用户解锁后继续。
- 修复 SDK 平台初始化后，应用正常启动。设备日志确认 BGE 加载成功：dimension=512，input_ids / attention_mask / token_type_ids 为 34（INT32）。
- 智能文件分类页正常读取已有 100 个文件、当前模型和 02:00–04:00 时间设置。
- 使用手机已有的 DeepSeek 配置和 Responses 协议测试连接，界面显示“连接成功，请保存配置后使用”；没有更改或重新保存用户密钥。
- 文件问答发送一条电赛资料检索问题，得到中文回答并附检索文件来源。此验证证明链路可用，不等同于检索质量评测；原问题末尾主题词截断的问题随后修复。
- 充电期间的后台分类已通过真实 Pi 工具调用生成 12 条待确认建议，页面展示分类与理由；没有自动接受不确定结果。
- 手动批次真机完成 20 个文件：已归类 18、待确认 2、保留 0、失败 0，界面提示剩余 38 个可继续处理。待确认累计 14 条。此批次完成后停止按钮已经消失，未把随后点击计作“中途停止成功”证据。
- 系统 WorkScheduler 的定时唤醒无法用本次短时测试证明每天准点执行；该接口本身是延迟调度。调度条件及停止/接管策略由自动测试验证。

## 真机发现并修复的 SDK 平台问题

### 模式匹配

| 一级根因 | 二级根因 | 三级根因 | Error message 模式 | 匹配依据 |
| --- | --- | --- | --- | --- |
| JSError | ReferenceError | 尝试访问的变量未定义 | `<name> is not defined` | 真机 `TextEncoder is not defined`，SDK index.js 模块初始化帧 |

15:34:18 的启动崩溃显示 `Reason:ReferenceError`，`Error message:TextEncoder is not defined`，首个应用帧为 `@shixu/pi-agent-harmony/index.js:2027:14`。SDK TypeBox 依赖在模块加载时构造 TextEncoder，适配层原先在所有 import 完成后才初始化。

处理：把平台初始化变成优先执行的模块副作用；补齐 Harmony native Blob 与标准 FormData polyfill。后者用于 OpenAI SDK 的请求体类型判断，即使文本请求也会访问 FormData。主机回归明确移除浏览器/Node 全局对象，防止被主机自带全局掩盖。

编译阶段另修复 es2abc 对未加引号的 async return 方法、for 初始化中的 yield 表达式的解析差异；AST 变换只调整语法表示，未改写 SDK 的协议逻辑。

## 保留限制

- HTTP 先缓冲再由 SDK 解析 SSE，暂不逐 token 渲染。
- 分类阈值未用标注集校准；一文件一向量及提取/token 长度限制仍存在。
- 后台受系统调度、生命周期和网络约束，不保证整点启动。失败保留重试状态，不能假定所有文件都已分类。
- 真机截图、完整日志与用户文件内容均保留在临时目录，没有提交到仓库。
