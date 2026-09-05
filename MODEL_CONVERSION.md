# BGE-Small-ZH v1.5 (INT8) 模型转换说明

本仓库在 HarmonyOS 应用中使用本地向量 Embedding 模型做**关键词扩展**（把用户配置的关键词向量化后做语义相似扩展）。模型文件为 MindSpore Lite 格式（`.ms`），放在 `entry/src/main/resources/rawfile/models/` 下供 `rawfile` API 读取。

## 产物

| 文件 | 说明 |
| --- | --- |
| `entry/src/main/resources/rawfile/models/bge-small-zh-v1.5-int8.ms` | MindSpore Lite 模型（**权重 INT8 量化**，约 25MB） |
| `entry/src/main/resources/rawfile/models/tokenizer.json` | BGE 分词器（运行 embedding 必需） |
| `entry/src/main/resources/rawfile/models/config.json` | 模型配置元数据 |

## 来源

- 模型: [BAAI/bge-small-zh-v1.5](https://huggingface.co/BAAI/bge-small-zh-v1.5)（24M 参数，`hidden_size=512`，句向量 512 维）
- FP32 ONNX: [Xenova/bge-small-zh-v1.5](https://huggingface.co/Xenova/bge-small-zh-v1.5) 的 `onnx/model.onnx`（约 90MB）
- 转换工具: MindSpore Lite 2.3.0 `converter_lite`（Linux x64，脚本自动下载官方发布包）
- 量化: converter `--configFile` 后训练量化，`quant_type=WEIGHT_QUANT, bit_num=8`（权重 int8，激活保持 fp32）

> 为什么不直接用现成 int8 ONNX（`model_quantized.onnx`）？
> 它的计算图含 `DynamicQuantizeLinear` / `MatMulInteger` 算子，MindSpore Lite 2.x ONNX 解析器不支持；
> 因此改为 FP32 ONNX + converter 自带的权重量化，产出真正 int8 权重的 `.ms`。

## 转换步骤

```bash
bash scripts/convert_bge_small_zh_ms.sh
```

脚本完成四件事：

1. 下载 `onnx/model.onnx`（FP32）、`tokenizer.json`、`config.json`（hf-mirror 优先，HuggingFace/GitCode 兜底）
2. 下载并解压 MindSpore Lite 官方 Linux x64 包（优先 2.3.0），定位 `converter_lite` 并设置 `LD_LIBRARY_PATH`
3. 用如下配置做权重 int8 量化转换（模型输入固定 batch=1、seq=512）：

   ```bash
   # quant.cfg
   [common_quant_param]
   quant_type=WEIGHT_QUANT
   bit_num=8
   min_quant_weight_size=0
   min_quant_weight_channel=0

   converter_lite \
     --fmk=ONNX \
     --modelFile=bge-small-zh-v1.5-fp32.onnx \
     --outputFile=bge-small-zh-v1.5-int8 \
     --configFile=quant.cfg \
     --inputShape="input_ids:1,512;attention_mask:1,512;token_type_ids:1,512"
   ```

4. 复制 `bge-small-zh-v1.5-int8.ms`（与 tokenizer/config）到 `entry/src/main/resources/rawfile/models/`

## 运行期要点

- **句向量维度：512**（`config.json` 的 `hidden_size=512`；不要沿用 MiniLM 项目的 384 假设）
- 输入：`input_ids` / `attention_mask` / `token_type_ids`（`int64[1, 512]`）
- 输出：`last_hidden_state`（fp32，形状 `[1, 512, 512]`）——**句向量取 [CLS] 行的 512 维**（BGE v1.5 官方 CLS pooling），使用前需 L2 归一化
- 文本编码前需用同源 `tokenizer.json` 做分词；中文无需加 query 前缀（v1.5 已优化无指令检索）
- HarmonyOS 端 MindSpore Lite 运行时已由 DevEco SDK 提供（`libmindspore_lite_ndk.so`），示例：`entry/src/main/ets/ai/model/EmbeddingModel.ets`

## 已验证

- `model_quantized.onnx`（22.9MB，int8 QDQ）转换失败：`not support onnx data type MatMulInteger / DynamicQuantizeLinear`
- FP32 ONNX + `WEIGHT_QUANT(bit_num=8)` 转换成功：`CONVERT RESULT SUCCESS:0`，输出 25MB `.ms`（2.3.0 converter 生成，模型与推理运行时同为 2.3.0）
- 转换器 2.3.0 / 2.6.0 均支持 `--configFile` 后训练量化（2.4.0 未测 CLI 全量参数，弃用）
- **端到端推理**（2.3.0 运行时 + C API；工具见 `build/model-conv/run_embed.c`、`tokenize_keyword.py`）：
  - 输入“发票”→ tokens `[CLS] 发 票 [SEP]`（ids `[101, 1355, 4873, 102]`），输出 `last_hidden_state[1,512,512]`，CLS 行 512 维，L2 范数 6.20
  - 相似度（余弦）：“发票-报销” 0.551、“报销-转账” 0.552、“发票-旅游” 0.436 —— 同类财务词相近、与无关词区分，符合语义 embedding 预期
- ⚠️ 2.3.0 C API 的 model/context 析构存在 double-free 缺陷（测试程序跳过析构，由进程退出回收）；模型可正常加载与推理

## 2.3.0 vs 2.6.0 转换器对比（实测）

同一份 FP32 ONNX + 同一份 `quant.cfg`（WEIGHT_QUANT / bit 8）分别转换：

| 项 | 2.3.0 转换版（现役 rawfile） | 2.6.0 转换版 |
| --- | --- | --- |
| 体积 | 25,701,280 B | 约 25MB |
| md5 | `5491f20a…`（内部版本戳/布局不同，故 md5 不同） | `e3d2480…` |
| 输出向量（发票） | 与 2.6.0 版**逐位一致**（max\|diff\| = 0.0） | 相同 |
| 延时（同一 2.6.0 运行时，warmup10×loop50，2 线程） | Avg 59.393ms / Min 57.403ms | Avg 59.576ms / Min 57.631ms |
| 延时（2.3.0-built 在 2.3.0 运行时基线） | Avg 61.738ms | 不能加载（版本不兼容） |

**结论**：转换器版本不影响模型数学结果，性能差异（0.3%）在噪声范围内 → **保留 2.3.0 版**（兼容 2.3 及以上运行时，2.6.0 版无法在 2.3.0 运行时加载）。设备运行时版本会带来约 4% 的延时差异（2.6.0 运行时略快），与转换器无关。

## 怎么让模型"输出近义词"（关键词扩展）

原理：Embedding 模型不是词库，不直接生成近义词；**近义词 = 向量空间里的余弦最近邻**。三步即可：

1. **维护候选词表**：文件关键词、LLM `extractKeywords` 结果、热词积累，存 `keyword_embeddings` 表或 rawfile JSON；
2. **批量编码入库**：启动时对每个候选词调 `model.encode(word)`，存 512 维向量（注意 L2 归一化）；
3. **查询扩展**：用户输入关键词 → `encode` → 与候选库逐条余弦 → 按阈值过滤 + top-k 返回。

实测（20 词候选表，查询 Top-6，工具 `build/model-conv/syn_expand.py`）：

- 「报销」→ 报销单 **0.93** / 报销流程 **0.86** / 报税 0.73 / 转账 0.55 / 发票 0.55 / 收款 0.55
- 「发票」→ 机票 0.71 / 收款 0.57 / 报销单 0.56 / 报税 0.55 / 付款 0.54 / 税务 0.53
- 「旅游」→ 差旅费 0.66 / 酒店 0.59 / 出差 0.49 / 签证 0.47 / 项目 0.46 / 机票 0.45
- 「工作」→ 工作总结 0.77 / 项目 0.56 / 付款 0.50 / 税务 0.49 / 收款 0.49 / 文档 0.48

ArkTS 侧接入骨架：

```typescript
const qv = await embeddingModel.encode(keyword)   // 512 维，先 L2 归一化
const cands = await keywordRepo.getAllEmbeddings() // {keyword, vec}[]
const tops = cands
  .map(c => ({ word: c.keyword, sim: cosine(qv, c.vec) }))
  .filter(x => x.sim >= 0.45)                       // 阈值按词表规模 0.45~0.55 调
  .sort((a, b) => b.sim - a.sim)
  .slice(0, 6)
// tops[].word 即"近义词"列表，用于规则匹配/搜索扩展
```

提示：词表越大召回越准；阈值过低会引入弱相关词（如 发票→机票），建议以 0.5 为起点调试。

## 备选源

若 HuggingFace 不可达，可切换镜像：

- hf-mirror: `https://hf-mirror.com/Xenova/bge-small-zh-v1.5/resolve/main/onnx/model.onnx`
- GitCode 镜像: `https://gitcode.com/hf_mirrors/Xenova/bge-small-zh-v1.5`（同名 `onnx/model.onnx`）
- ModelScope: `BAAI/bge-small-zh-v1.5`