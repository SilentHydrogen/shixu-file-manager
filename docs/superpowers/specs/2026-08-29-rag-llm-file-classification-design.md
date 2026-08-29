# 基于 LLM 的 RAG 文件智能整理功能设计文档

## 文档信息

- **项目名称**: 拾序文件管理器
- **功能模块**: RAG + LLM 智能文件整理
- **设计日期**: 2026-08-29
- **目标平台**: HarmonyOS (鸿蒙系统)
- **技术栈**: ArkUI, ArkTS, C++ NAPI, SQLite, ONNX Runtime

---

## 1. 概述

### 1.1 功能目标

为拾序文件管理器增加基于 LLM 的 RAG（检索增强生成）功能，实现对鸿蒙系统下载目录中文件的智能分析和自动归纳。系统通过本地轻量级 Embedding 模型进行向量检索，结合云端 LLM API 进行分类决策，帮助用户将散落的文件高效地整理到预设或自定义的"收纳箱"中。

### 1.2 核心特性

- **混合架构**: 本地向量检索 + 云端 LLM 决策
- **分层文件处理**: 根据文件类型采用不同的内容提取策略（PDF/PPT/Word/TXT/鸿蒙特色文件）
- **结构化规则定义**: 用户通过表单配置收纳箱规则，关键词自动向量扩展
- **硬约束执行**: LLM 必须严格遵守用户定义的规则，不可违背
- **智能触发**: 充电时、夜间特定时段、或用户手动触发文件分析
- **引用管理**: 收纳箱存储文件引用/链接，不物理移动原文件（也支持实体文件夹模式）
- **分层向量存储**: 热数据（近期文件）保留向量，冷数据仅保留元数据

### 1.3 设计原则

- **最小化修改**: 复用现有 UI 界面和数据结构，扩展而非重构
- **性能优化**: C++ 负责文件解析，批量处理减少跨语言调用
- **权限边界清晰**: LLM 仅可调用预定义的 3 个工具，不可直接访问文件系统
- **用户可控**: 所有自动化操作可配置，低置信度建议需用户确认

---

## 2. 系统架构

### 2.1 整体架构图

```
┌─────────────────────────────────────────┐
│         ArkTS UI Layer (ArkUI)          │
│  - 收纳箱管理界面                        │
│  - 规则配置表单                          │
│  - 文件预览与归纳结果展示                │
└──────────────────┬──────────────────────┘
                   │
┌──────────────────▼──────────────────────┐
│      Business Logic Layer (ArkTS)       │
│  - 文件扫描调度器                        │
│  - RAG 编排服务                          │
│  - 收纳箱规则引擎                        │
│  - 任务队列管理（充电/定时触发）         │
└──────────────────┬──────────────────────┘
                   │
┌──────────────────▼──────────────────────┐
│       RAG Service Layer (ArkTS)         │
│  ┌─────────────────────────────────┐   │
│  │  LLM Agent Orchestrator         │   │
│  │  - Tool Dispatcher              │   │
│  │  - Prompt Builder               │   │
│  │  - Response Parser              │   │
│  └─────────────────────────────────┘   │
│                                         │
│  Tools (封装给 LLM 调用):               │
│  ├─ search_similar_files()             │
│  ├─ match_collection_rules()           │
│  └─ expand_keywords()                  │
└──────────────────┬──────────────────────┘
                   │
┌──────────────────▼──────────────────────┐
│      Data & Model Layer                 │
│  ┌─────────────┐  ┌──────────────────┐ │
│  │ SQLite DB   │  │ Vector Extension │ │
│  │ - 文件元数据 │  │ - Embedding 存储 │ │
│  │ - 收纳箱配置 │  │ - 相似度检索     │ │
│  │ - 规则定义   │  │ - 关键词索引     │ │
│  └─────────────┘  └──────────────────┘ │
│                                         │
│  ┌─────────────────────────────────┐   │
│  │  Embedding Model (ONNX)         │   │
│  │  - MiniLM-L6-v2 或同类轻量模型   │   │
│  └─────────────────────────────────┘   │
└──────────────────┬──────────────────────┘
                   │
┌──────────────────▼──────────────────────┐
│    Native Layer (C++ NAPI)              │
│  - PDF 解析 (PDFium 或 MuPDF)           │
│  - Office 解析 (LibreOffice Kit)        │
│  - 鸿蒙特色格式解析                      │
│  - 文本提取优化                          │
└─────────────────────────────────────────┘
```

### 2.2 核心数据流

1. **文件收纳触发** → 扫描监控文件夹 → 提取文件信息（C++ 解析）
2. **特征提取** → Embedding 模型生成向量 → 存入 SQLite Vector Extension
3. **RAG 检索** → LLM 调用工具 → 向量库检索 + 规则匹配
4. **归纳决策** → LLM 返回分类建议 → 应用硬约束规则验证
5. **用户确认** → 低置信度建议需人工确认，高置信度自动执行
6. **建立引用** → 在收纳箱创建文件链接/快捷方式

### 2.3 调用链示意

```
[定时触发] 
   ↓
[RagScheduler.executeTask()]
   ↓
[FileWatcher.getUnclassifiedFiles()]  ← 获取待处理文件
   ↓
[RagOrchestrator.classify()]
   ↓
[NativeFileParser] ← 提取文件内容（C++ 层）
   ↓
[EmbeddingService] ← 生成向量并存储
   ↓
[LlmApiClient.chat()] ← 调用云端 LLM（OpenAI SDK）
   ↓ (LLM 返回 tool_calls)
   ↓
[RagTools 执行]:
  - search_similar_files()
  - match_collection_rules()
  - expand_keywords()
   ↓ (返回工具结果给 LLM)
   ↓
[LlmApiClient.chat()] ← LLM 综合分析并给出建议
   ↓
[PermissionGuard + RuleEngine] ← 应用硬约束规则验证
   ↓
[ClassificationResult] ← 返回归纳建议
   ↓
[UI 展示/自动执行]
```

---

## 3. 核心接口设计

### 3.1 RAG 服务主接口

```typescript
// entry/src/main/ets/services/RagService.ets

export class RagService {
  /**
   * 批量分析文件并返回归纳建议
   */
  async analyzeFiles(
    fileUris: string[], 
    userContext: UserContext
  ): Promise<ClassificationResult[]>
  
  /**
   * 根据用户自定义规则扩展关键词
   */
  async expandKeywords(keywords: string[]): Promise<string[]>
  
  /**
   * 手动触发 RAG 分析任务
   */
  async triggerManualAnalysis(): Promise<void>
}
```

### 3.2 LLM Agent 工具接口

#### 工具 1: search_similar_files

根据关键词或文件特征，从向量库检索相似文件。

**输入参数**:
```typescript
{
  query: string          // 查询文本
  top_k: number          // 返回 Top K 结果
  file_types?: string[]  // 可选：限定文件类型
}
```

**输出结果**:
```typescript
[
  {
    file_uri: string
    similarity_score: number
    file_name: string
    file_type: string
    collection?: string    // 已归入的收纳箱（如有）
  }
]
```

#### 工具 2: match_collection_rules

根据文件信息匹配用户定义的收纳箱规则。

**输入参数**:
```typescript
{
  file_info: {
    name: string
    type: string
    size: number
    content_summary: string
    extracted_keywords: string[]
  }
}
```

**输出结果**:
```typescript
[
  {
    collection_id: string
    collection_name: string
    match_confidence: number  // 0-1
    matched_rules: string[]   // 命中的规则描述
  }
]
```

#### 工具 3: expand_keywords

基于向量相似度扩展用户定义的关键词。

**输入参数**:
```typescript
{
  keywords: string[]
  max_expansions: number  // 每个关键词最多扩展数量
}
```

**输出结果**:
```typescript
[
  {
    original: string
    expanded: string[]
    relevance_scores: number[]
  }
]
```

### 3.3 LLM API 客户端

```typescript
// entry/src/main/ets/services/llm/LlmApiClient.ets

export class LlmApiClient {
  /**
   * 使用 OpenAI npm SDK 构建请求
   */
  async chat(request: LlmRequest): Promise<LlmResponse>
  
  /**
   * 配置 LLM 服务商
   * - 默认支持 OpenAI
   * - 后续可兼容自定义 provider（通过 endpoint 适配）
   */
  configure(config: {
    provider: 'openai' | 'custom'
    api_key: string
    endpoint: string
    model: string
  }): void
}
```

**使用示例**:
```typescript
import OpenAI from 'openai'

const client = new OpenAI({
  apiKey: config.api_key,
  baseURL: config.endpoint  // 自定义端点支持
})

const response = await client.chat.completions.create({
  model: config.model,
  messages: messages,
  tools: toolDefinitions
})
```

### 3.4 权限边界控制

```typescript
// entry/src/main/ets/services/rag/PermissionGuard.ets

export class PermissionGuard {
  /**
   * 验证工具调用是否合法
   * - 只能调用预定义的 3 个工具
   * - 不能访问收纳箱规则以外的配置
   * - 不能直接操作文件系统
   */
  validateToolCall(toolName: string, args: any): boolean
  
  /**
   * 过滤敏感信息
   * - 文件完整路径 → 仅保留文件名
   * - 用户隐私数据 → 不传给 LLM
   */
  sanitizeFileInfo(fileInfo: FileInfo): SanitizedFileInfo
  
  /**
   * 硬约束规则验证
   * - 用户明确指定的规则不可违背
   */
  enforceHardRules(
    suggestion: ClassificationResult, 
    userRules: Rule[]
  ): boolean
}
```

---

## 4. 任务调度与触发机制

### 4.1 调度器配置

```typescript
// entry/src/main/ets/services/scheduler/RagScheduler.ets

export interface ScheduleConfig {
  // 充电时触发
  triggerOnCharging: boolean
  
  // 夜间定时触发
  nightlySchedule?: {
    enabled: boolean
    startHour: number  // 如 22 表示晚上 10 点
    endHour: number    // 如 6 表示早上 6 点
  }
  
  // 手动触发（始终可用）
  manualTriggerEnabled: boolean
  
  // 批量处理阈值
  batchThreshold?: {
    minFiles: number      // 最少累积文件数
    maxWaitHours: number  // 最长等待时间（小时）
  }
  
  // 网络要求
  requireWifi: boolean  // 是否必须 WiFi 环境
}
```

### 4.2 系统事件监听

使用鸿蒙系统 API 监听：
- **充电状态**: `@ohos.batteryInfo`
- **网络状态**: `@ohos.net.connection`
- **定时任务**: `@ohos.resourceschedule.backgroundTaskManager`

```typescript
// entry/src/main/ets/services/scheduler/SystemEventMonitor.ets

export class SystemEventMonitor {
  onChargingStateChange(callback: (isCharging: boolean) => void): void
  onWifiStateChange(callback: (isConnected: boolean) => void): void
  registerTimedTask(config: { hour: number, minute: number, callback: () => void }): void
  dispose(): void
}
```

### 4.3 文件监控服务

```typescript
// entry/src/main/ets/services/file/FileWatcher.ets

export class FileWatcher {
  /**
   * 添加监控目录（如鸿蒙下载目录）
   */
  addWatchDir(dirPath: string): void
  
  /**
   * 获取未归纳的文件列表
   */
  async getUnclassifiedFiles(): Promise<FileInfo[]>
  
  /**
   * 标记文件为已处理
   */
  markAsProcessed(fileUri: string): void
  
  /**
   * 获取待处理文件数量（用于 UI 显示）
   */
  getUnprocessedCount(): number
}
```

---

## 5. 数据存储设计

### 5.1 数据库 Schema

#### 表 1: files（文件元数据表）

```sql
CREATE TABLE IF NOT EXISTS files (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  uri TEXT UNIQUE NOT NULL,
  name TEXT NOT NULL,
  type TEXT NOT NULL,
  size INTEGER NOT NULL,
  path TEXT NOT NULL,
  created_time INTEGER NOT NULL,
  modified_time INTEGER NOT NULL,
  content_hash TEXT,
  is_processed INTEGER DEFAULT 0,
  processed_time INTEGER,
  content_summary TEXT,
  extracted_keywords TEXT
);
```

#### 表 2: file_embeddings（向量存储表）

使用 SQLite Vector Extension（如 sqlite-vss）:

```sql
CREATE VIRTUAL TABLE IF NOT EXISTS file_embeddings USING vec0(
  file_id INTEGER PRIMARY KEY,
  embedding FLOAT[384],
  embedding_type TEXT DEFAULT 'content'
);
```

#### 表 3: keyword_embeddings（关键词向量表）

```sql
CREATE VIRTUAL TABLE IF NOT EXISTS keyword_embeddings USING vec0(
  keyword_id INTEGER PRIMARY KEY,
  keyword TEXT UNIQUE NOT NULL,
  embedding FLOAT[384],
  usage_count INTEGER DEFAULT 0,
  last_used INTEGER
);
```

#### 表 4: collections（收纳箱配置表）

```sql
CREATE TABLE IF NOT EXISTS collections (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  icon TEXT,
  color TEXT,
  description TEXT,
  rules TEXT NOT NULL,
  created_time INTEGER NOT NULL,
  is_preset INTEGER DEFAULT 0
);
```

#### 表 5: file_collection_refs（文件-收纳箱关联表）

```sql
CREATE TABLE IF NOT EXISTS file_collection_refs (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  file_id INTEGER NOT NULL,
  collection_id INTEGER NOT NULL,
  ref_type TEXT DEFAULT 'link',
  confidence REAL,
  created_time INTEGER NOT NULL,
  created_by TEXT DEFAULT 'llm',
  FOREIGN KEY (file_id) REFERENCES files(id),
  FOREIGN KEY (collection_id) REFERENCES collections(id),
  UNIQUE(file_id, collection_id)
);
```

#### 表 6: vector_storage_tiers（分层存储管理表）

```sql
CREATE TABLE IF NOT EXISTS vector_storage_tiers (
  file_id INTEGER PRIMARY KEY,
  tier TEXT NOT NULL,
  last_accessed INTEGER NOT NULL,
  access_count INTEGER DEFAULT 1,
  FOREIGN KEY (file_id) REFERENCES files(id)
);
```

#### 表 7: rag_analysis_logs（RAG 分析历史表）

```sql
CREATE TABLE IF NOT EXISTS rag_analysis_logs (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  batch_id TEXT NOT NULL,
  file_count INTEGER NOT NULL,
  start_time INTEGER NOT NULL,
  end_time INTEGER,
  llm_tokens_used INTEGER,
  status TEXT,
  error_message TEXT
);
```

### 5.2 向量检索服务

```typescript
// entry/src/main/ets/services/vector/VectorSearchService.ets

export class VectorSearchService {
  async storeFileEmbedding(
    fileId: number, 
    embedding: Float32Array, 
    type: 'content' | 'keywords' | 'filename'
  ): Promise<void>
  
  async storeKeywordEmbedding(keyword: string, embedding: Float32Array): Promise<void>
  
  async searchSimilar(
    queryEmbedding: Float32Array, 
    topK: number, 
    filters?: SearchFilters
  ): Promise<SearchResult[]>
  
  async expandKeywords(
    keywords: string[], 
    maxExpansions: number
  ): Promise<KeywordExpansion[]>
  
  async promoteToCold(fileIds: number[]): Promise<void>
  async promoteToHot(fileIds: number[]): Promise<void>
  async cleanupColdVectors(olderThanDays: number): Promise<number>
}
```

### 5.3 分层存储策略

**热数据（Hot）规则**:
- 近 30 天内创建或访问的文件
- 访问次数 ≥ 3 次
- 预设监控文件夹中的所有文件

**冷数据（Cold）规则**:
- 超过 30 天未访问
- 访问次数 < 3 且超过 7 天

**管理策略**:
- 定期（每周）评估并降级冷数据
- 冷数据的向量可被清理，但保留元数据
- 访问冷数据时自动提升为热数据

---

## 6. 规则引擎设计

### 6.1 收纳箱规则模型

```typescript
// entry/src/main/ets/model/CollectionRule.ets

export class CollectionRule {
  id: number
  collectionId: number
  priority: number
  conditions: RuleCondition[]
  enabled: boolean
  createdTime: number
}

export interface RuleCondition {
  type: ConditionType
  operator: OperatorType
  value: string | number | string[]
}

export enum ConditionType {
  FILE_NAME = 'file_name',
  FILE_TYPE = 'file_type',
  FILE_SIZE = 'file_size',
  KEYWORDS = 'keywords',
  CONTENT_CONTAINS = 'content_contains',
  DATE_RANGE = 'date_range',
  SOURCE_PATH = 'source_path'
}

export enum OperatorType {
  EQUALS = 'equals',
  CONTAINS = 'contains',
  STARTS_WITH = 'starts_with',
  ENDS_WITH = 'ends_with',
  GREATER_THAN = 'greater_than',
  LESS_THAN = 'less_than',
  IN = 'in',
  MATCHES = 'matches'
}
```

### 6.2 规则引擎

```typescript
// entry/src/main/ets/services/rule/RuleEngine.ets

export class RuleEngine {
  /**
   * 根据规则匹配文件到收纳箱
   * 如果多个规则命中，返回优先级最高的
   */
  matchRules(fileInfo: FileInfo, rules: CollectionRule[]): RuleMatchResult | null
  
  /**
   * 验证 LLM 建议是否违反硬约束
   */
  validateLlmSuggestion(
    fileInfo: FileInfo,
    llmSuggestion: ClassificationResult,
    userRules: CollectionRule[]
  ): ValidationResult
  
  /**
   * 关键词匹配（调用向量扩展）
   */
  private async matchKeywords(
    fileKeywords: string[], 
    ruleKeywords: string[]
  ): Promise<boolean>
}
```

### 6.3 硬约束执行流程

1. LLM 返回归纳建议
2. RuleEngine 检查是否有用户规则明确命中
3. 如有命中规则 → 强制应用该规则，忽略 LLM 建议
4. 如无命中规则 → 采用 LLM 建议
5. 验证最终结果的合法性

### 6.4 预设规则库

支持四种场景预设：
- **学生场景**: 课程资料、作业与考试、论文资料、学习笔记
- **商务人士场景**: 合同文档、财务报表、会议纪要、项目文档
- **摄影师场景**: 原片、精修作品、客户交付、素材库
- **通用场景**: 文档、图片、视频、音频、压缩包

---

## 7. C++ 原生层设计

### 7.1 文件解析接口

```typescript
// entry/src/main/cpp/types/libentry/index.d.ts

export const FileParser: {
  parsePdf(uri: string): Promise<ParseResult>
  parseOffice(uri: string, fileType: string): Promise<ParseResult>
  parseText(uri: string, encoding?: string): Promise<string>
  parseHarmonyFile(uri: string, fileType: string): Promise<ParseResult>
  parseBatch(files: Array<{uri: string, type: string}>): Promise<ParseResult[]>
}

export interface ParseResult {
  success: boolean
  content: string
  summary: string
  metadata: {
    pageCount?: number
    wordCount?: number
    author?: string
    title?: string
    createdDate?: number
    keywords?: string[]
  }
  error?: string
}
```

### 7.2 文件类型支持

| 文件类型 | 解析库 | 提取内容 |
|---------|--------|---------|
| PDF | PDFium 或 MuPDF | 文本、元数据（页数、作者、标题） |
| Word (.docx) | LibreOffice Kit | 文本、标题、作者 |
| PowerPoint (.pptx) | LibreOffice Kit | 文本、标题 |
| Excel (.xlsx) | LibreOffice Kit | 工作表名称、单元格文本 |
| TXT | 标准库 | 完整文本（支持多种编码） |
| 鸿蒙备忘录 | 自定义解析 | 标题、正文、标签 |
| 鸿蒙笔记 | 自定义解析 | 标题、正文、附件列表 |

### 7.3 性能优化

```typescript
// entry/src/main/ets/services/performance/PerformanceOptimizer.ets

export class PerformanceOptimizer {
  /**
   * 批处理策略：减少跨语言调用开销
   */
  static async batchProcess<T>(
    items: T[], 
    processor: (batch: T[]) => Promise<any[]>,
    batchSize: number = 10
  ): Promise<any[]>
  
  /**
   * 文件大小阈值判断
   * 大文件（>10MB）使用流式处理
   */
  static shouldUseStreaming(fileSize: number): boolean
  
  /**
   * 缓存解析结果（基于文件 hash）
   */
  static getCachedParse(fileHash: string): ParseResult | null
  static cacheParse(fileHash: string, result: ParseResult): void
}
```

---

## 8. UI 集成方案

### 8.1 最小化修改原则

**现有 UI 保持不变**:
- 收纳箱列表页面
- 文件预览页面
- 桌面小组件

**新增 UI 元素**:
1. 主页顶部：RAG 状态横幅（仅在有待处理文件时显示）
2. 设置页面：新增"智能整理"分组
3. 收纳箱编辑页：新增"整理规则"配置区
4. 确认对话框：显示 LLM 归纳建议

### 8.2 RAG 状态横幅

```typescript
// entry/src/main/ets/pages/Index.ets

@Builder RagStatusBanner() {
  Row() {
    Image($r('app.media.ic_ai')).width(24).height(24)
    
    Column() {
      Text(`${this.unprocessedCount} 个文件待整理`)
      Text(`上次分析：${this.formatTime(this.lastAnalysisTime)}`)
    }
    .layoutWeight(1)
    
    Button('立即整理')
      .onClick(() => this.triggerManualAnalysis())
  }
  .padding(16)
  .backgroundColor('#F5F7FA')
}
```

### 8.3 规则配置界面

扩展现有收纳箱编辑页面，新增规则配置区域：

- 规则条件列表（文件名、类型、关键词等）
- 添加/删除条件按钮
- 优先级设置
- 规则启用/禁用开关

### 8.4 整理结果确认对话框

当 LLM 建议需要用户确认时显示：

- 文件列表（带复选框）
- 每个文件的建议收纳箱
- LLM 给出的归纳理由
- 批量确认/取消按钮

---

## 9. Embedding 模型集成

### 9.1 模型选型

**推荐模型**: `sentence-transformers/all-MiniLM-L6-v2`

- **向量维度**: 384
- **模型大小**: ~23MB（ONNX 格式）
- **推理速度**: 移动设备可接受（~50ms/句）
- **多语言支持**: 中英文均可

### 9.2 ONNX Runtime 集成

```typescript
// entry/src/main/ets/services/embedding/EmbeddingService.ets

export class EmbeddingService {
  /**
   * 初始化 ONNX 模型
   * 模型文件: entry/src/main/resources/rawfile/models/minilm-l6-v2.onnx
   */
  async init(): Promise<void>
  
  /**
   * 生成文本的 Embedding
   */
  async encode(text: string): Promise<Float32Array>
  
  /**
   * 批量生成（性能优化）
   */
  async encodeBatch(texts: string[]): Promise<Float32Array[]>
  
  dispose(): void
}
```

### 9.3 向量相似度计算

使用余弦相似度：

```typescript
function cosineSimilarity(a: Float32Array, b: Float32Array): number {
  let dotProduct = 0
  let normA = 0
  let normB = 0
  
  for (let i = 0; i < a.length; i++) {
    dotProduct += a[i] * b[i]
    normA += a[i] * a[i]
    normB += b[i] * b[i]
  }
  
  return dotProduct / (Math.sqrt(normA) * Math.sqrt(normB))
}
```

---

## 10. LLM Prompt 设计

### 10.1 System Prompt

```
你是一个文件整理助手，帮助用户将散落的文件归纳到合适的收纳箱中。

用户已经定义了若干收纳箱，每个收纳箱都有明确的整理规则。你的任务是：
1. 分析文件的名称、类型、内容摘要和关键词
2. 使用提供的工具检索相似文件、匹配规则、扩展关键词
3. 根据检索结果和规则匹配情况，判断文件应该归入哪个收纳箱
4. 给出归纳理由（50 字以内）

重要约束：
- 你必须严格遵守用户定义的规则，不得违背
- 如果用户规则已经明确命中，必须优先使用该规则
- 如果多个规则冲突，选择优先级最高的
- 如果没有合适的收纳箱，返回 "未分类"

可用工具：
- search_similar_files: 检索相似文件
- match_collection_rules: 匹配收纳箱规则
- expand_keywords: 扩展关键词
```

### 10.2 User Prompt 模板

```
请分析以下文件并给出归纳建议：

文件名: {fileName}
文件类型: {fileType}
文件大小: {fileSize}
内容摘要: {contentSummary}
提取的关键词: {extractedKeywords}

可用的收纳箱:
{collectionList}

请使用工具进行分析，并给出归纳建议。
```

### 10.3 工具调用示例

```json
{
  "role": "assistant",
  "content": null,
  "tool_calls": [
    {
      "id": "call_1",
      "type": "function",
      "function": {
        "name": "expand_keywords",
        "arguments": "{\"keywords\": [\"项目\", \"需求\"], \"max_expansions\": 5}"
      }
    },
    {
      "id": "call_2",
      "type": "function",
      "function": {
        "name": "search_similar_files",
        "arguments": "{\"query\": \"项目需求文档\", \"top_k\": 5, \"file_types\": [\"pdf\", \"docx\"]}"
      }
    }
  ]
}
```

---

## 11. 错误处理与异常场景

### 11.1 文件解析失败

- **原因**: 文件损坏、格式不支持、权限不足
- **处理**: 记录错误日志，标记为"解析失败"，不影响其他文件处理

### 11.2 LLM API 调用失败

- **原因**: 网络错误、API 限流、余额不足
- **处理**: 
  1. 自动重试（最多 3 次，指数退避）
  2. 失败后标记任务状态为"待重试"
  3. 用户可在统计页面查看失败原因

### 11.3 向量检索无结果

- **原因**: 向量库为空、查询过于泛化
- **处理**: 返回空结果给 LLM，由 LLM 基于规则匹配做决策

### 11.4 规则冲突

- **原因**: 多个规则同时命中同一文件
- **处理**: 按优先级、规则具体性、首次匹配顺序解决

### 11.5 系统资源不足

- **原因**: 内存不足、存储空间不足
- **处理**: 
  1. 暂停 RAG 任务
  2. 清理冷数据向量
  3. 通知用户

---

## 12. 安全与隐私

### 12.1 数据隐私

- **本地处理**: 文件内容提取和 Embedding 完全在本地完成
- **云端传输**: 仅传输文件元数据和内容摘要（不超过 500 字符）
- **敏感信息过滤**: 文件完整路径、用户个人信息不传给 LLM
- **API Key 安全**: 存储在鸿蒙加密首选项中

### 12.2 权限控制

- **文件访问**: 仅访问用户授权的监控文件夹
- **网络访问**: 仅在 WiFi 环境下调用云端 API（可配置）
- **后台任务**: 使用鸿蒙 BackgroundTaskManager 合法申请后台权限

### 12.3 LLM 权限边界

- **工具白名单**: 只能调用预定义的 3 个工具
- **参数验证**: 所有工具调用参数经过验证
- **操作限制**: 不能直接操作文件系统，不能访问系统配置

---

## 13. 性能指标

### 13.1 目标性能

| 指标 | 目标值 |
|-----|--------|
| 单文件解析时间 | < 1 秒（PDF < 50 页） |
| Embedding 生成时间 | < 100ms/文件 |
| 向量检索时间 | < 50ms（1 万条记录） |
| LLM API 响应时间 | < 3 秒 |
| 批量处理速度 | > 20 文件/分钟 |
| 内存占用 | < 100MB（分析过程） |
| 存储占用 | ~100KB/文件（含向量） |

### 13.2 优化策略

1. **批处理**: 每批 10-20 个文件
2. **并行处理**: 文件解析和 Embedding 生成并行
3. **缓存**: 基于文件 hash 缓存解析结果
4. **分层存储**: 冷数据向量按需加载
5. **流式处理**: 大文件分块处理

---

## 14. 测试策略

### 14.1 单元测试

- RuleEngine 规则匹配逻辑
- VectorSearchService 相似度检索
- PermissionGuard 权限验证
- FileParser C++ 模块

### 14.2 集成测试

- RAG 完整流程（文件输入 → 归纳建议）
- LLM API 调用与工具执行
- 数据库读写与向量存储
- 系统事件触发

### 14.3 性能测试

- 1000 个文件批量处理
- 向量库 10 万条记录检索
- 内存占用压力测试
- 长时间后台运行稳定性

### 14.4 用户测试

- 四种场景预设的准确性
- 自定义规则的易用性
- 整理建议的合理性
- UI 响应流畅度

---

## 15. 实施计划

### 阶段 1: 基础设施（2 周）

- [ ] 数据库 Schema 设计与实现
- [ ] SQLite Vector Extension 集成
- [ ] ONNX Runtime 集成与 Embedding 模型加载
- [ ] C++ 文件解析模块框架

### 阶段 2: 核心服务（3 周）

- [ ] VectorSearchService 实现
- [ ] RuleEngine 实现
- [ ] LLM API 客户端（OpenAI SDK）
- [ ] RAG 工具封装（3 个工具）
- [ ] PermissionGuard 实现

### 阶段 3: 业务逻辑（2 周）

- [ ] RagOrchestrator 实现
- [ ] RagScheduler 实现
- [ ] FileWatcher 实现
- [ ] SystemEventMonitor 实现
- [ ] 预设规则库

### 阶段 4: UI 集成（1 周）

- [ ] 主页 RAG 状态横幅
- [ ] 规则配置界面
- [ ] 确认对话框
- [ ] 设置页面扩展

### 阶段 5: C++ 优化（2 周）

- [ ] PDF 解析实现（PDFium/MuPDF）
- [ ] Office 解析实现（LibreOffice Kit）
- [ ] 鸿蒙特色文件解析
- [ ] 批处理优化

### 阶段 6: 测试与优化（2 周）

- [ ] 单元测试与集成测试
- [ ] 性能测试与优化
- [ ] 用户测试与反馈迭代
- [ ] 文档完善

**总计**: 12 周（约 3 个月）

---

## 16. 风险与挑战

### 16.1 技术风险

| 风险 | 影响 | 缓解措施 |
|-----|------|---------|
| SQLite Vector Extension 在鸿蒙系统兼容性问题 | 高 | 预研验证，准备备选方案（纯 SQL 实现） |
| ONNX Runtime 在鸿蒙设备性能不足 | 中 | 降级到云端 Embedding API |
| C++ 解析库依赖复杂，编译困难 | 中 | 简化依赖，使用轻量级库 |
| LLM API 成本超预期 | 中 | 限制调用频率，提供免费额度告警 |

### 16.2 业务风险

| 风险 | 影响 | 缓解措施 |
|-----|------|---------|
| 用户对 AI 整理结果不满意 | 高 | 提供人工确认机制，可撤销操作 |
| 规则配置过于复杂 | 中 | 提供预设模板，简化配置界面 |
| 隐私担忧（上传文件到云端） | 中 | 明确说明仅传输摘要，提供本地模式 |

---

## 17. 未来扩展

### 17.1 短期扩展（6 个月内）

- 支持更多文件类型（视频、音频元数据提取）
- 自定义 LLM Provider（兼容更多云服务商）
- 学习增强模式（基于用户反馈优化规则）
- 多设备同步（鸿蒙分布式）

### 17.2 长期展望（1 年以上）

- 完全本地化 LLM（设备端大模型）
- 多模态分析（图像内容理解）
- 智能标签系统（自动生成标签）
- 协同整理（家庭/团队共享收纳箱）

---

## 18. 附录

### 18.1 依赖库清单

| 库名 | 版本 | 用途 |
|-----|------|------|
| openai | ^4.x | LLM API 客户端 |
| sqlite-vss | ^0.1.x | SQLite 向量扩展 |
| onnxruntime | ^1.x | Embedding 模型推理 |
| PDFium / MuPDF | - | PDF 解析（C++） |
| LibreOffice Kit | - | Office 文档解析（C++） |

### 18.2 参考文档

- [HarmonyOS API 参考](https://developer.harmonyos.com/cn/docs/documentation/doc-references-V3/syscap-0000001281201602-V3)
- [OpenAI API 文档](https://platform.openai.com/docs/api-reference)
- [SQLite Vector Extension](https://github.com/asg017/sqlite-vss)
- [ONNX Runtime](https://onnxruntime.ai/docs/)
- [Sentence Transformers](https://www.sbert.net/)

### 18.3 术语表

- **RAG**: Retrieval-Augmented Generation（检索增强生成）
- **Embedding**: 文本的向量表示
- **收纳箱**: 用户定义的文件分类容器
- **硬约束**: 用户规则的强制执行
- **分层存储**: 热数据和冷数据分离管理
- **工具调用**: LLM 通过 Function Calling 调用预定义函数

---

## 19. 总结

本设计文档详细描述了基于 LLM 的 RAG 文件智能整理功能的完整架构和实现方案。系统采用**轻量级集成方案**，通过本地向量检索和云端 LLM 决策相结合的方式，为鸿蒙系统用户提供智能、高效、隐私安全的文件整理体验。

核心设计原则：
1. **最小化修改**: 复用现有 UI 和数据结构
2. **用户可控**: 所有自动化操作可配置，硬约束规则优先
3. **性能优化**: C++ 负责计算密集型任务，批处理减少开销
4. **权限边界**: LLM 仅能调用预定义工具，不可直接操作文件系统
5. **渐进增强**: 支持从简单规则到复杂 AI 分析的平滑过渡

预期效果：
- 用户可在 **1 分钟内** 配置收纳箱规则
- 系统可在 **3 分钟内** 完成 100 个文件的智能归纳
- 分类准确率达到 **85% 以上**（基于预设规则和 LLM 决策）
- 用户手动调整率低于 **20%**

本方案为拾序文件管理器注入 AI 能力，助力其成为鸿蒙生态中最智能的文件管理应用。
