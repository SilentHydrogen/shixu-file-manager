# BGE-Small-ZH v1.5（INT8）嵌入向量模型移植报告

- **项目**：拾序文件管理器（HarmonyOS / ArkTS）
- **报告日期**：2026-08-30
- **范围**：本地嵌入式向量模型（关键词扩展/语义检索）的移植、验证与使用建议

---

## 1. 摘要

模型文件级移植**已完成并验证**：`bge-small-zh-v1.5-int8.ms`（MindSpore Lite INT8 权重量化，25.7MB）连同分词器、配置已放入 `entry/src/main/resources/rawfile/models/`，转换工具链可复现，语义/性能实测通过。

**代码级接入仍受运行时阻塞**：`EmbeddingModel.ets` 已移除随机向量，当前在 MindSpore Lite NAPI 运行时未随工程提供时明确降级为不可用；业务使用关键词检索降级。项目向量维度已对齐为 **512**。

---

## 2. 移植状况

### 2.1 目标

让 BGE-Small-ZH v1.5 中文向量 embedding 模型在鸿蒙应用内离线运行，用于**关键词向量化与近义词/语义扩展**（收纳箱规则关键词自动扩展、语义检索）。

### 2.2 已完成 ✅

| 项目 | 状态 | 证据 |
| --- | --- | --- |
| 模型获取与格式转换 | ✅ | BAAI/bge-small-zh-v1.5 → Xenova FP32 ONNX → MindSpore Lite 2.3.0 `WEIGHT_QUANT(bit8)` → `.ms`（MSL2 格式，INT8 权重） |
| 模型落盘 | ✅ | `rawfile/models/bge-small-zh-v1.5-int8.ms` 25,701,280B；`tokenizer.json` 439,125B；`config.json` 716B |
| 可复现工具链 | ✅ | `scripts/convert_bge_small_zh_ms.sh`（多镜像下载 + 量化转换 + 落盘，自动重跑） |
| 文档 | ✅ | `MODEL_CONVERSION.md`（来源/步骤/实测记录） |
| 转换验证 | ✅ | `CONVERT RESULT SUCCESS:0`；文件头 `MSL2` 签名；int8 QDQ ONNX（`MatMulInteger`/`DynamicQuantizeLinear`）被明确判定不支持后改走 FP32+权重量化 |
| 兼容性对比 | ✅ | 2.3.0 vs 2.6.0 转换版：向量逐位一致、延时差 0.3%（噪声）；**保留 2.3.0 版**（兼容性最好，2.6.0 版无法在 2.3.0 运行时加载） |
| 推理验证 | ✅ | 端到端跑通“发票/报销/转账/旅游”：`last_hidden_state[1,512,512]`，CLS 行 512 维；x86 单次约 59~60ms |
| 语义验证 | ✅ | 相似度矩阵 + 近义词 Top-K（见 §3.3），财务/差旅/工作类词簇区分正确 |

### 2.3 未完成 / 风险 ⚠️

| 项 | 说明 | 优先级 |
| --- | --- | --- |
| MindSpore Lite NAPI 尚未接入 | `EmbeddingModel.ets` 在运行时未提供时拒绝返回伪向量；`.ms` 已交付，端侧 NAPI/ABI 仍待接入 | P0 |
| MindSpore Lite 运行时接入未编码 | rawfile 读取 → 内存 buffer → `MSModelBuild` → 推理 → 取 CLS 行，整条链路待实现 | P0 |
| 维度已对齐 | `EmbeddingModel.EMBEDDING_DIM=512`、`DatabaseConfig.VECTOR_DIMENSION=512`，与模型实际 **512** 一致 | ✅ |
| 关键词扩展未接入 | `DatabaseConfig.TABLE_KEYWORD_EMBEDDINGS` 常量已定义，但 `keyword_embeddings` 表与扩展流程未实现 | P1 |
| 真机未验证 | 当前验证基于 x86 Linux 的 2.3.0 运行时；鸿蒙真机（DevEco SDK `libmindspore_lite_ndk.so`）加载/性能/内存待测 | P1 |
| 运行时版本确认 | 需确认设备端 NDK 运行时 ≥2.3.0；转换器与运行时版本必须一致（本次统一 2.3.0） | P1 |
| C API 析构缺陷 | 2.3.0 C API 的 model/context 析构存在 double-free（测试程序绕过，端侧需规避或依赖修复版运行时） | P2 |

---

## 3. 嵌入式嵌入向量模型状态

### 3.1 文件清单

| 文件 | 大小 | 用途 |
| --- | --- | --- |
| `bge-small-zh-v1.5-int8.ms` | 25,701,280 B（≈24.5 MiB，md5 `5491f20a…`） | MindSpore Lite 推理模型（权重 INT8） |
| `tokenizer.json` | 439,125 B | 中文分词（WordPiece），推理前必须 |
| `config.json` | 716 B | 模型元数据（`hidden_size=512` 等） |

### 3.2 模型规格

| 项 | 值 |
| --- | --- |
| 基础模型 | [BAAI/bge-small-zh-v1.5](https://huggingface.co/BAAI/bge-small-zh-v1.5)（BERT 架构：4 层 / 8 头 / hidden 512 / 24M 参数） |
| 格式 | MindSpore Lite `.ms`（v2，MSL2 flatbuffer；2.3.0 转换版） |
| 量化 | 权重 INT8（`WEIGHT_QUANT, bit_num=8`），激活 FP32；FP32 90MB → 25.7MB |
| 输入 | `input_ids` / `attention_mask` / `token_type_ids`，`int64[1,512]` |
| 输出 | `last_hidden_state`，`fp32[1,512,512]` |
| 句向量 | **取 [CLS] 行（首行），512 维**，使用前需 L2 归一化（BGE v1.5 官方 CLS pooling） |
| 前缀规则 | 中文检索/编码**不需要** query 前缀（v1.5 已优化无指令检索） |

### 3.3 质量与性能实测

- **语义质量**（20 词候选表，余弦 Top-K）：
  - 「报销」→ 报销单 0.93 / 报销流程 0.86 / 报税 0.73 / 转账 0.55 / 发票 0.55 / 收款 0.55
  - 「发票」→ 机票 0.71 / 收款 0.57 / 报销单 0.56 / 报税 0.55 / 付款 0.54 / 税务 0.53
  - 「旅游」→ 差旅费 0.66 / 酒店 0.59 / 出差 0.49 / 签证 0.47 / 项目 0.46 / 机票 0.45
  - 「工作」→ 工作总结 0.77 / 项目 0.56 / 付款 0.50 / 税务 0.49 / 收款 0.49 / 文档 0.48
- **性能**（x86 Linux，2.3.0 运行时，2 线程，warmup10 + loop50）：
  - 单次推理 Avg ≈ **59.4ms**（Min 57.4ms）
  - 首次加载 Prepare ≈ 163ms（建议启动预热）
  - 2.6.0 运行时略快 ~4%，但需配套 2.6.0 转换版，收益小、兼容性差，不推荐
- **转换器版本对比结论**：2.3.0 与 2.6.0 转换产物推理结果逐位一致、性能无实质差异；保留 2.3.0 版。

### 3.4 已知限制

1. MindSpore Lite ONNX 解析器不支持 int8 QDQ 图（`DynamicQuantizeLinear`/`MatMulInteger`）——现方案为 FP32 ONNX + 转换期权重量化，已绕过。
2. 模型真实维度 **512**，项目当前数据库与模型常量已统一为 512。
3. 单次输入最长 512 token；中文长文本需截断/分块。
4. 单字或生僻词的近义词召回有限，建议词表 + 阈值配合使用。

---

## 4. 模型使用建议

### 4.1 接入前置（P0，必须）

1. **统一维度为 512**：
   - `entry/src/main/ets/ai/model/EmbeddingModel.ets`：`EMBEDDING_DIM = 512`
   - `entry/src/main/ets/data/database/DatabaseConfig.ets`：`VECTOR_DIMENSION = 512`
   - 检查所有依赖该常量的地方（`VectorStore`/`VectorIndex`/`FileEmbedding` 为 JSON 数组存储，运行时维度自动兼容，但校验逻辑需同步）。
2. **实现 `EmbeddingModel` 真推理**：
   - rawfile 读取：`getContext().resourceManager.getRawFileContent('models/bge-small-zh-v1.5-int8.ms')`；
   - MindSpore Lite 加载：内存 buffer 方式 `MSModelBuild(model, data, size, …)`（或先落沙箱再 `BuildFromFile`）；
   - 输入填 `int64[1,512]` 三张量；输出取 `last_hidden_state` 的 **CLS 行** 512 个 float，做 **L2 归一化**后返回 `number[]`。
3. **运行时版本确认**：核对 DevEco SDK 的 `libmindspore_lite_ndk.so` ≥ 2.3.0；保持转换器（2.3.0）与运行时一致。

### 4.2 关键词扩展（近义词）方案

> 模型不“生成”近义词；近义词 = 向量空间余弦最近邻。

1. **候选词表**：文件关键词 / LLM `extractKeywords` 结果 / 高频词的累积，存 `keyword_embeddings` 表（表名常量已定义在 `DatabaseConfig.TABLE_KEYWORD_EMBEDDINGS`）。
2. **批量入库**：启动/增量时对候选词逐个 `encode()` 存 512 维向量（L2 归一化后存储）。
3. **查询扩展**：

```typescript
const qv = await embeddingModel.encode(keyword)
const cands = await keywordRepo.getAllEmbeddings()          // [{keyword, vec}]
const near = cands
  .map(c => ({ word: c.keyword, sim: cosine(qv, c.vec) }))
  .filter(x => x.sim >= 0.5)                                // 阈值 0.45~0.55，按词表规模调
  .sort((a, b) => b.sim - a.sim)
  .slice(0, 6)
```

4. **阈值建议**：从 0.5 起步；词表越大、覆盖领域越准；0.45 以下容易混入弱相关词（如 发票→机票 0.71 已属跨界）。

### 4.3 性能与资源建议

- 固定输入形状 `1×512`，避免动态 shape；线程数 2~4（ARM 大核优先）。
- 首次加载约 160ms+，建议启动后异步预热一次；批量关键词编码串行或限并发。
- `tokenizer.json` 可常驻内存（429KB）；分词建议复用 fast tokenizer 逻辑（本项目演示用 stdlib 实现，端侧可用 ArkTS 实现或携带 vocab）。
- 内存预估：模型 25.7MB + Lite 运行时 + 中间张量（512×512×4B ≈ 1MB）在真机可接受；真机实测为准。
- 若真机性能不足优先排查：线程绑定、fp16 开关（仅影响激活，需重新转换验证）、模型固定 batch。

### 4.4 验收建议

| 层级 | 用例 | 通过标准 |
| --- | --- | --- |
| 单元 | `encode()` 维度 | = 512 |
| 单元 | L2 归一化 | ‖v‖ ≈ 1.0 |
| 单元 | 同词重复编码 | 余弦 ≈ 1.0 |
| 单元 | 近义词 Top-K | 「报销」应含 报销单/报销流程（≥0.5） |
| 真机 | 加载耗时 / 单次推理耗时 / RSS 内存 | 记录基线，与 x86（60ms）对比 |
| 端到端 | 关键词扩展 → 收纳箱规则命中 | 命中率提升 ≥ 阈值预期 |

---

## 5. 下一步路线图

- **P0**：维度 512 对齐 → `EmbeddingModel` 接入 MindSpore Lite → 单元测试（维度/归一化/相似度）。
- **P1**：`keyword_embeddings` 建表 + 候选词批量入库 + 关键词扩展服务；真机性能/内存基线。
- **P2**：文件内容向量化接入 `RagAnalysisService`；冷热向量分层；扩展词表自动学习。

---

## 附录 A：关键文件

| 路径 | 说明 |
| --- | --- |
| `entry/src/main/resources/rawfile/models/bge-small-zh-v1.5-int8.ms` | 交付模型（INT8，512 维） |
| `entry/src/main/resources/rawfile/models/tokenizer.json` | 分词器 |
| `entry/src/main/resources/rawfile/models/config.json` | 模型配置 |
| `scripts/convert_bge_small_zh_ms.sh` | 一键转换/复现脚本 |
| `MODEL_CONVERSION.md` | 转换与实测说明 |
| `entry/src/main/ets/ai/model/EmbeddingModel.ets` | NAPI 运行时适配点；无运行时不返回伪向量 |
| `entry/src/main/ets/data/database/DatabaseConfig.ets` | `VECTOR_DIMENSION=512` |

## 附录 B：参考

- [BAAI/bge-small-zh-v1.5](https://huggingface.co/BAAI/bge-small-zh-v1.5)
- [Xenova/bge-small-zh-v1.5（ONNX）](https://huggingface.co/Xenova/bge-small-zh-v1.5)
- [MindSpore Lite 转换工具](https://www.mindspore.cn/lite/docs/zh-CN/r2.3.0/converter/converter_tool.html)