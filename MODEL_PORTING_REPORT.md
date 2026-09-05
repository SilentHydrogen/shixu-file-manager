# BGE-Small-ZH v1.5 INT8 端侧移植报告

## 结论

本地 `.ms` 模型已接入 HarmonyOS MindSpore Lite Kit，端侧真机推理已跑通。应用不调用
远端 Embeddings API；远端 LLM 仅用于用户授权后的文本分析和问答。

真机验证结果：

- 设备：nova 14。
- 模型：`bge-small-zh-v1.5-int8.ms`，约 25 MB。
- 分词器：`tokenizer.json`，WordPiece。
- 输入：`input_ids`、`attention_mask`、`token_type_ids`，长度 512。
- 输出：`last_hidden_state` 的 CLS 行，512 维。
- 后处理：L2 归一化。
- 运行日志：`Local embedding ready: dimension=512`。

## 代码接入

- `entry/src/main/ets/ai/model/EmbeddingModel.ets`
  - `resourceManager.getRawFileContent()` 读取模型和分词器。
  - `mindSporeLite.loadModelFromBuffer()` 加载模型。
  - 按输入 tensor 名称写入三个 `Int32Array`。
  - `Model.predict()` 执行推理。
  - 校验输出长度并返回归一化 512 维向量。
- `entry/src/main/ets/ai/KeywordExpansionService.ets`
  - 初始化分类关键词和中英文同义词。
  - 关键词向量最近邻扩展。
  - 无 LLM 时按文件名和扩展名做语义分类。
- `entry/src/main/ets/data/repository/KeywordEmbeddingRepository.ets`
  - 将关键词、分类和 512 维向量写入 `keyword_embeddings`。
- `entry/src/main/ets/service/RagAnalysisService.ets`
  - 文件向量化、混合检索、排序和多 chunk RAG。

## 数据兼容

数据库版本为 3。升级时清理旧维度向量，并创建 `keyword_embeddings`、分类字段和相关索引。
`VectorIndex` 会拒绝空向量或维度不匹配向量，并使用完整余弦相似度计算。

## 降级策略

模型加载或推理失败时：

1. 记录实际错误。
2. 禁用本地语义分数和向量扩展。
3. 保留分词、同义词词库、字段权重和词法排序。
4. 不生成随机向量，不调用远端 Embeddings API。

## 模型来源与转换约束

模型基于 `BAAI/bge-small-zh-v1.5`，隐藏维度 512。转换、量化及替换步骤见
`MODEL_CONVERSION.md`。替换模型时必须同时验证输入名称、输入 dtype、序列长度、输出布局和
向量维度；维度变化需要数据库迁移。

## 验证清单

- HAP 构建成功。
- ArkTS 单元测试可编译；Linux 命令行运行器存在平台挂起限制。
- 真机加载和推理成功，向量维度 512。
- 本地词库初始化成功。
- 应用安装、启动，无应用 crash。
- WorkScheduler 注册不再因重复 workId 抛出 `9700005`。
