# 本地 Embedding 与 LLM RAG 集成

## 当前架构

向量嵌入不调用远端 Embeddings API。应用通过 HarmonyOS MindSpore Lite Kit 加载
`entry/src/main/resources/rawfile/models/bge-small-zh-v1.5-int8.ms`，在设备本地生成
512 维、L2 归一化的 BGE 向量。OpenAI 兼容接口只负责可选的聊天、摘要、分类和问答。

主要模块：

- `EmbeddingModel.ets`：加载 `.ms` 和 `tokenizer.json`，WordPiece 分词，本地推理和批量编码。
- `KeywordExpansionService.ets`：维护分类词、同义词和关键词向量，执行语义扩展及离线分类。
- `KeywordEmbeddingRepository.ets`：持久化关键词向量。
- `RagAnalysisService.ets`：文件分析、混合检索、多 chunk 问答和批处理状态。
- `LLMService.ets`：远端 LLM 调用、授权检查和上传内容边界。
- `ContentBoundary.ets`：限制单文件和多上下文上传内容。
- `BackgroundAnalysisScheduler.ets`、`DirectoryMonitor.ets`：延迟任务和目录变化接线。

## RAG 流程

文件入库：

1. 从文件名、扩展名和可读文本提取本地关键词。
2. 本地 BGE 模型生成文件向量。
3. 根据分类关键词向量和同义词词库生成离线分类。
4. 用户已配置 LLM 且明确同意上传时，可补充摘要、关键词和建议分类。
5. 文件向量、分类和分析日志写入本地数据库。

检索：

1. 对查询做中英文分词。
2. 从本地同义词词库和 `keyword_embeddings` 最近邻扩展关键词。
3. 计算词法命中、字段权重和本地向量相似度。
4. 融合词法分数与语义分数并排序。
5. 问答按查询相关度从每个文件选取多个 chunk，最多上传受限上下文。

本地模型加载或推理失败时，系统保留词法搜索；不会生成随机伪向量，也不会回退到已废弃的远端 Embeddings API。

## 隐私与授权

- 远端 LLM 默认关闭，API Key 由系统安全存储管理。
- 用户必须在 LLM 设置页明确开启“允许上传受限文件片段”。
- `LLMService` 的摘要、关键词、分类、分析和问答入口都检查授权。
- 所有上传正文都经过 `ContentBoundary.clampUploadContent()` 或
  `clampUploadContexts()`；页面不能自行截取后绕过边界。
- 用户撤销授权后，后续 LLM 请求立即被拒绝；本地 embedding、词法检索和离线分类仍可用。

## AI 整理

AI 分类只产生待确认建议。用户可接受或拒绝：

- 接受：更新文件分类并持久化，移除待确认项。
- 拒绝：记录拒绝状态并移除待确认项，不修改文件分类。
- 待确认建议保存在 Preferences，页面重启后可恢复。

## 后台运行

`EntryAbility.onCreate()` 初始化数据库和 `RagAnalysisService`，接入未处理文件队列、
`DirectoryMonitor` 和 `BackgroundAnalysisScheduler`。延迟任务由
`RagWorkSchedulerExtensionAbility` 承接；重复注册前先检查已有 work，旧 Ability 注册会被替换。

## 配置 LLM

1. 打开 LLM 设置。
2. 配置服务 Base URL、模型、API Key 和 API 协议（自动、Chat Completions 或 Responses）。
3. 测试连接。
4. 阅读隐私说明并单独开启片段上传授权。

支持 OpenAI Chat Completions 和 Responses 协议的云端或自建服务。DeepSeek Responses 兼容接口选择“Responses”，Base URL 填写 `https://api.deepseek.com`（客户端自动请求 `/responses`）；也可直接填入包含 `/responses` 的完整地址。服务不需要也不应提供 Embeddings API。

## 验证

```bash
devecocli build
devecocli check lint
devecocli run --module entry --device <serial>
```

真机日志应包含：

```text
Local embedding ready: dimension=512
RAG background work registered
```

再次启动时第二行可变为：

```text
RAG background work already registered
```
