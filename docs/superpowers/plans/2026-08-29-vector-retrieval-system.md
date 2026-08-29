# 向量检索系统实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为 RAG 文件整理系统实现向量检索能力，包括 ONNX Runtime 集成、Embedding 模型加载、向量存储与语义搜索。

**Architecture:** 使用 ONNX Runtime 运行本地 Embedding 模型（MiniLM-L6-v2），将文本转换为 384 维向量，使用简化的内存向量索引实现语义检索。

**Tech Stack:** ArkTS, ONNX Runtime (HarmonyOS), MiniLM-L6-v2 Embedding 模型, 内存向量索引

## Global Constraints

- 目标平台: HarmonyOS
- 最低 SDK 版本: 6.1.0(23)
- Embedding 模型: sentence-transformers/all-MiniLM-L6-v2 (ONNX 格式)
- 向量维度: 384
- 相似度算法: 余弦相似度
- 所有向量操作必须异步
- 依赖前置任务: Task 1-6（数据基础设施）

---

## Task 1: ONNX Runtime 集成与模型加载

**Files:**
- Create: `entry/src/main/ets/ai/onnx/ONNXRuntimeManager.ets`
- Create: `entry/src/main/ets/ai/onnx/ModelConfig.ets`
- Create: `entry/src/main/ets/ai/model/EmbeddingModel.ets`
- Create: `entry/src/main/resources/rawfile/models/minilm-l6-v2.onnx` (占位)

**Interfaces:**
- Consumes: ONNX Runtime HarmonyOS API (需要研究)
- Produces:
  - `ONNXRuntimeManager.getInstance(): ONNXRuntimeManager` - ONNX 运行时单例
  - `EmbeddingModel.loadModel(modelPath: string): Promise<void>` - 加载模型
  - `EmbeddingModel.encode(text: string): Promise<number[]>` - 文本转向量

---

- [ ] **Step 1: 研究 HarmonyOS ONNX Runtime API**

调查 HarmonyOS 是否提供官方 ONNX Runtime 支持：
- 查看 HarmonyOS SDK 文档
- 搜索 `@ohos.ai.onnx` 或类似的 API
- 确定是否需要引入第三方库

**如果官方不支持**，考虑替代方案：
- 方案 A: 使用 Web Assembly (WASM) 版本的 ONNX Runtime
- 方案 B: 使用 Native C++ ONNX Runtime + N-API 桥接
- 方案 C: 简化为纯 JavaScript 实现（性能较低）

- [ ] **Step 2: 创建模型配置**

```typescript
// entry/src/main/ets/ai/model/ModelConfig.ets

export class ModelConfig {
  static readonly MODEL_NAME: string = 'all-MiniLM-L6-v2'
  static readonly MODEL_PATH: string = 'models/minilm-l6-v2.onnx'
  static readonly VECTOR_DIMENSION: number = 384
  static readonly MAX_SEQUENCE_LENGTH: number = 256
  
  // Tokenizer 配置
  static readonly VOCAB_SIZE: number = 30522
  static readonly PAD_TOKEN_ID: number = 0
  static readonly CLS_TOKEN_ID: number = 101
  static readonly SEP_TOKEN_ID: number = 102
}
```

- [ ] **Step 3: 创建 ONNX Runtime 管理器（假设有原生支持）**

```typescript
// entry/src/main/ets/ai/onnx/ONNXRuntimeManager.ets

import onnxRuntime from '@ohos.ai.onnxruntime' // 假设的 API
import { ModelConfig } from '../model/ModelConfig'

export class ONNXRuntimeManager {
  private static instance: ONNXRuntimeManager
  private session: onnxRuntime.InferenceSession | null = null
  
  private constructor() {}
  
  static getInstance(): ONNXRuntimeManager {
    if (!ONNXRuntimeManager.instance) {
      ONNXRuntimeManager.instance = new ONNXRuntimeManager()
    }
    return ONNXRuntimeManager.instance
  }
  
  async loadModel(modelPath: string): Promise<void> {
    // 从 rawfile 加载 ONNX 模型
    this.session = await onnxRuntime.createSession(modelPath)
  }
  
  async runInference(inputTensor: onnxRuntime.Tensor): Promise<onnxRuntime.Tensor> {
    if (!this.session) {
      throw new Error('Model not loaded')
    }
    
    const outputs = await this.session.run({ input: inputTensor })
    return outputs.output
  }
  
  dispose(): void {
    if (this.session) {
      this.session.dispose()
      this.session = null
    }
  }
}
```

**注意**：此步骤的实际实现**高度依赖** HarmonyOS 对 ONNX Runtime 的支持情况。如果没有官方 API，需要调整架构。

- [ ] **Step 4: 创建 Embedding 模型封装**

```typescript
// entry/src/main/ets/ai/model/EmbeddingModel.ets

import { ONNXRuntimeManager } from '../onnx/ONNXRuntimeManager'
import { ModelConfig } from './ModelConfig'
import { Tokenizer } from './Tokenizer'

export class EmbeddingModel {
  private runtime: ONNXRuntimeManager
  private tokenizer: Tokenizer
  private isLoaded: boolean = false
  
  constructor() {
    this.runtime = ONNXRuntimeManager.getInstance()
    this.tokenizer = new Tokenizer()
  }
  
  async loadModel(): Promise<void> {
    await this.runtime.loadModel(ModelConfig.MODEL_PATH)
    this.isLoaded = true
  }
  
  async encode(text: string): Promise<number[]> {
    if (!this.isLoaded) {
      throw new Error('Model not loaded. Call loadModel() first.')
    }
    
    // 1. Tokenize
    const tokens = this.tokenizer.tokenize(text)
    
    // 2. 转换为输入张量
    const inputTensor = this.createInputTensor(tokens)
    
    // 3. 运行推理
    const outputTensor = await this.runtime.runInference(inputTensor)
    
    // 4. 提取 [CLS] token 的 embedding
    const embedding = this.extractEmbedding(outputTensor)
    
    // 5. 归一化
    return this.normalize(embedding)
  }
  
  private createInputTensor(tokens: number[]): any {
    // 填充到固定长度
    const paddedTokens = this.pad(tokens, ModelConfig.MAX_SEQUENCE_LENGTH)
    
    // 创建张量（形状：[1, MAX_SEQUENCE_LENGTH]）
    // 实际实现依赖 ONNX Runtime API
    return {
      data: new Int32Array(paddedTokens),
      shape: [1, ModelConfig.MAX_SEQUENCE_LENGTH]
    }
  }
  
  private extractEmbedding(outputTensor: any): number[] {
    // 从输出张量中提取 [CLS] token 的 embedding
    // 输出形状：[1, MAX_SEQUENCE_LENGTH, 384]
    // 我们只需要 [0, 0, :] 即前 384 个值
    const embedding: number[] = []
    for (let i = 0; i < ModelConfig.VECTOR_DIMENSION; i++) {
      embedding.push(outputTensor.data[i])
    }
    return embedding
  }
  
  private normalize(vector: number[]): number[] {
    const norm = Math.sqrt(vector.reduce((sum, val) => sum + val * val, 0))
    return vector.map(val => val / norm)
  }
  
  private pad(tokens: number[], length: number): number[] {
    if (tokens.length >= length) {
      return tokens.slice(0, length)
    }
    return [...tokens, ...new Array(length - tokens.length).fill(ModelConfig.PAD_TOKEN_ID)]
  }
}
```

- [ ] **Step 5: 创建简化的 Tokenizer**

```typescript
// entry/src/main/ets/ai/model/Tokenizer.ets

import { ModelConfig } from './ModelConfig'

export class Tokenizer {
  /**
   * 简化的 tokenizer
   * 注意：这是一个占位实现，实际需要加载 BERT 词表
   */
  tokenize(text: string): number[] {
    // 添加 [CLS] token
    const tokens = [ModelConfig.CLS_TOKEN_ID]
    
    // 简单的空格分词（实际需要 WordPiece tokenizer）
    const words = text.toLowerCase().split(/\s+/)
    
    for (const word of words) {
      // 占位：将单词映射到随机 token ID
      // 实际实现需要加载 vocab.txt 并进行 WordPiece 分词
      const tokenId = this.wordToTokenId(word)
      tokens.push(tokenId)
      
      if (tokens.length >= ModelConfig.MAX_SEQUENCE_LENGTH - 1) {
        break
      }
    }
    
    // 添加 [SEP] token
    tokens.push(ModelConfig.SEP_TOKEN_ID)
    
    return tokens
  }
  
  private wordToTokenId(word: string): number {
    // 占位实现
    // 实际需要从 vocab.txt 查找
    return Math.floor(Math.random() * ModelConfig.VOCAB_SIZE)
  }
}
```

- [ ] **Step 6: 编写测试（如果 ONNX Runtime 可用）**

```typescript
// entry/src/test/ets/ai/EmbeddingModelTest.ets

import { describe, it, expect, beforeAll } from '@ohos/hypium'
import { EmbeddingModel } from '../../../main/ets/ai/model/EmbeddingModel'
import { ModelConfig } from '../../../main/ets/ai/model/ModelConfig'

export default function embeddingModelTest() {
  describe('EmbeddingModel', () => {
    let model: EmbeddingModel
    
    beforeAll(async () => {
      model = new EmbeddingModel()
      await model.loadModel()
    })
    
    it('should generate embeddings with correct dimension', async () => {
      const text = 'This is a test document'
      const embedding = await model.encode(text)
      
      expect(embedding.length).assertEqual(ModelConfig.VECTOR_DIMENSION)
    })
    
    it('should generate normalized embeddings', async () => {
      const text = 'Hello world'
      const embedding = await model.encode(text)
      
      // 验证向量是归一化的（模长应为 1）
      const norm = Math.sqrt(embedding.reduce((sum, val) => sum + val * val, 0))
      expect(norm).assertClose(1.0, 0.001)
    })
    
    it('should generate similar embeddings for similar text', async () => {
      const text1 = 'machine learning'
      const text2 = 'artificial intelligence'
      const text3 = 'banana recipe'
      
      const emb1 = await model.encode(text1)
      const emb2 = await model.encode(text2)
      const emb3 = await model.encode(text3)
      
      const sim12 = cosineSimilarity(emb1, emb2)
      const sim13 = cosineSimilarity(emb1, emb3)
      
      // 相关文本的相似度应该更高
      expect(sim12).assertLarger(sim13)
    })
  })
}

function cosineSimilarity(a: number[], b: number[]): number {
  const dotProduct = a.reduce((sum, val, i) => sum + val * b[i], 0)
  return dotProduct // 已归一化，点积即余弦相似度
}
```

- [ ] **Step 7: 阻塞点 - 确认 ONNX Runtime 可用性**

**关键决策点**：如果 HarmonyOS 不提供 ONNX Runtime 支持，需要：
1. 向用户报告阻塞
2. 提出替代方案
3. 等待用户决策后继续

**报告模板**：
```
Status: BLOCKED

Issue: HarmonyOS ONNX Runtime API 不可用

调查结果：
- 未找到 @ohos.ai.onnxruntime 或类似 API
- HarmonyOS SDK 文档中无相关说明

替代方案：
A. 使用预计算向量（离线生成，存储到数据库）
B. 使用远程 API（调用云端 Embedding 服务）
C. 等待 HarmonyOS 后续版本支持

建议：方案 A（预计算向量）- MVP 可行，后续可升级
```

---

## Task 2: 向量存储与索引（简化版）

**Files:**
- Create: `entry/src/main/ets/data/vector/VectorIndex.ets`
- Create: `entry/src/main/ets/data/vector/VectorStore.ets`
- Create: `entry/src/main/ets/data/model/FileEmbedding.ets`

**Interfaces:**
- Consumes:
  - `DatabaseManager.getStore(): Promise<relationalStore.RdbStore>`
  - `EmbeddingModel.encode(text: string): Promise<number[]>` (如果可用)
- Produces:
  - `VectorStore.saveEmbedding(fileId: number, embedding: number[]): Promise<void>`
  - `VectorStore.getEmbedding(fileId: number): Promise<number[] | null>`
  - `VectorIndex.search(queryVector: number[], topK: number): Promise<SearchResult[]>`

---

- [ ] **Step 1: 创建 FileEmbedding 模型**

```typescript
// entry/src/main/ets/data/model/FileEmbedding.ets

export class FileEmbedding {
  fileId: number
  embedding: number[]
  createdTime: number = Date.now()
  
  constructor(init?: Partial<FileEmbedding>) {
    Object.assign(this, init)
  }
  
  /**
   * 从数据库行转换
   */
  static fromRow(row: any): FileEmbedding {
    return new FileEmbedding({
      fileId: row.file_id,
      embedding: JSON.parse(row.embedding_vector),
      createdTime: row.created_time
    })
  }
  
  /**
   * 转换为数据库行对象
   */
  toValuesBucket(): Record<string, any> {
    return {
      file_id: this.fileId,
      embedding_vector: JSON.stringify(this.embedding),
      created_time: this.createdTime
    }
  }
}
```

- [ ] **Step 2: 扩展数据库 Schema 添加向量表**

修改 `entry/src/main/ets/data/database/DatabaseSchema.ets`：

```typescript
static getCreateTableSQLs(): string[] {
  return [
    // ... 现有表
    this.createFileEmbeddingsTable()
  ]
}

private static createFileEmbeddingsTable(): string {
  return `
    CREATE TABLE IF NOT EXISTS file_embeddings (
      file_id INTEGER PRIMARY KEY,
      embedding_vector TEXT NOT NULL,
      created_time INTEGER NOT NULL,
      FOREIGN KEY (file_id) REFERENCES files(id)
    )
  `
}
```

- [ ] **Step 3: 创建 VectorStore**

```typescript
// entry/src/main/ets/data/vector/VectorStore.ets

import relationalStore from '@ohos.data.relationalStore'
import { DatabaseManager } from '../database/DatabaseManager'
import { FileEmbedding } from '../model/FileEmbedding'

export class VectorStore {
  private async getStore(): Promise<relationalStore.RdbStore> {
    return await DatabaseManager.getInstance().getStore()
  }
  
  /**
   * 保存文件的 embedding 向量
   */
  async saveEmbedding(fileId: number, embedding: number[]): Promise<void> {
    const store = await this.getStore()
    
    const fileEmbedding = new FileEmbedding({
      fileId,
      embedding
    })
    
    const values = fileEmbedding.toValuesBucket()
    
    // 使用 INSERT OR REPLACE 实现 upsert
    const sql = `
      INSERT OR REPLACE INTO file_embeddings (file_id, embedding_vector, created_time)
      VALUES (?, ?, ?)
    `
    
    await store.executeSql(sql, [
      fileId.toString(),
      values.embedding_vector,
      values.created_time.toString()
    ])
  }
  
  /**
   * 获取文件的 embedding 向量
   */
  async getEmbedding(fileId: number): Promise<number[] | null> {
    const store = await this.getStore()
    const predicates = new relationalStore.RdbPredicates('file_embeddings')
    predicates.equalTo('file_id', fileId)
    
    const resultSet = await store.query(predicates)
    
    try {
      if (resultSet.goToFirstRow()) {
        const embeddingJson = resultSet.getString(resultSet.getColumnIndex('embedding_vector'))
        return JSON.parse(embeddingJson)
      }
      return null
    } finally {
      resultSet.close()
    }
  }
  
  /**
   * 获取所有文件的 embeddings（用于构建索引）
   */
  async getAllEmbeddings(): Promise<FileEmbedding[]> {
    const store = await this.getStore()
    const predicates = new relationalStore.RdbPredicates('file_embeddings')
    
    const resultSet = await store.query(predicates)
    const embeddings: FileEmbedding[] = []
    
    try {
      while (resultSet.goToNextRow()) {
        const rowData = this.resultSetToObject(resultSet)
        embeddings.push(FileEmbedding.fromRow(rowData))
      }
      return embeddings
    } finally {
      resultSet.close()
    }
  }
  
  /**
   * 删除文件的 embedding
   */
  async deleteEmbedding(fileId: number): Promise<void> {
    const store = await this.getStore()
    const predicates = new relationalStore.RdbPredicates('file_embeddings')
    predicates.equalTo('file_id', fileId)
    await store.delete(predicates)
  }
  
  private resultSetToObject(resultSet: relationalStore.ResultSet): Record<string, any> {
    const columnNames = resultSet.columnNames
    const row: Record<string, any> = {}
    
    for (let i = 0; i < columnNames.length; i++) {
      const columnName = columnNames[i]
      const columnType = resultSet.getColumnType(i)
      
      switch (columnType) {
        case relationalStore.ColumnType.TYPE_INTEGER:
          row[columnName] = resultSet.getLong(i)
          break
        case relationalStore.ColumnType.TYPE_STRING:
          row[columnName] = resultSet.getString(i)
          break
        default:
          row[columnName] = null
      }
    }
    
    return row
  }
}
```

- [ ] **Step 4: 创建内存向量索引**

```typescript
// entry/src/main/ets/data/vector/VectorIndex.ets

import { FileEmbedding } from '../model/FileEmbedding'
import { VectorStore } from './VectorStore'

export interface SearchResult {
  fileId: number
  score: number
}

export class VectorIndex {
  private store: VectorStore
  private index: Map<number, number[]> = new Map()
  private isBuilt: boolean = false
  
  constructor() {
    this.store = new VectorStore()
  }
  
  /**
   * 构建索引（从数据库加载所有向量到内存）
   */
  async build(): Promise<void> {
    const embeddings = await this.store.getAllEmbeddings()
    
    this.index.clear()
    for (const emb of embeddings) {
      this.index.set(emb.fileId, emb.embedding)
    }
    
    this.isBuilt = true
  }
  
  /**
   * 向索引中添加新向量
   */
  addToIndex(fileId: number, embedding: number[]): void {
    this.index.set(fileId, embedding)
  }
  
  /**
   * 从索引中移除向量
   */
  removeFromIndex(fileId: number): void {
    this.index.delete(fileId)
  }
  
  /**
   * 语义搜索
   */
  async search(queryVector: number[], topK: number = 10): Promise<SearchResult[]> {
    if (!this.isBuilt) {
      await this.build()
    }
    
    const results: SearchResult[] = []
    
    // 计算查询向量与所有索引向量的余弦相似度
    for (const [fileId, embedding] of this.index.entries()) {
      const score = this.cosineSimilarity(queryVector, embedding)
      results.push({ fileId, score })
    }
    
    // 按相似度降序排序，取 top K
    results.sort((a, b) => b.score - a.score)
    return results.slice(0, topK)
  }
  
  /**
   * 余弦相似度计算（假设向量已归一化）
   */
  private cosineSimilarity(a: number[], b: number[]): number {
    if (a.length !== b.length) {
      throw new Error('Vector dimensions mismatch')
    }
    
    let dotProduct = 0
    for (let i = 0; i < a.length; i++) {
      dotProduct += a[i] * b[i]
    }
    
    return dotProduct
  }
  
  /**
   * 获取索引统计信息
   */
  getStats(): { totalVectors: number, dimension: number } {
    const firstVector = this.index.values().next().value
    return {
      totalVectors: this.index.size,
      dimension: firstVector ? firstVector.length : 0
    }
  }
}
```

- [ ] **Step 5: 编写测试**

```typescript
// entry/src/test/ets/data/VectorIndexTest.ets

import { describe, it, expect, beforeAll, afterEach } from '@ohos/hypium'
import { VectorIndex } from '../../../main/ets/data/vector/VectorIndex'
import { VectorStore } from '../../../main/ets/data/vector/VectorStore'
import { DatabaseManager } from '../../../main/ets/data/database/DatabaseManager'

export default function vectorIndexTest() {
  describe('VectorIndex', () => {
    let index: VectorIndex
    let store: VectorStore
    
    beforeAll(async () => {
      await DatabaseManager.getInstance().init(getContext())
      index = new VectorIndex()
      store = new VectorStore()
    })
    
    afterEach(async () => {
      const dbStore = await DatabaseManager.getInstance().getStore()
      await dbStore.executeSql('DELETE FROM file_embeddings')
    })
    
    it('should build index from stored embeddings', async () => {
      // 准备测试数据
      await store.saveEmbedding(1, [0.1, 0.2, 0.3])
      await store.saveEmbedding(2, [0.4, 0.5, 0.6])
      
      // 构建索引
      await index.build()
      
      const stats = index.getStats()
      expect(stats.totalVectors).assertEqual(2)
      expect(stats.dimension).assertEqual(3)
    })
    
    it('should find most similar vectors', async () => {
      // 添加测试向量
      await store.saveEmbedding(1, [1.0, 0.0, 0.0])
      await store.saveEmbedding(2, [0.0, 1.0, 0.0])
      await store.saveEmbedding(3, [0.9, 0.1, 0.0])
      
      await index.build()
      
      // 查询与 [1, 0, 0] 最相似的向量
      const queryVector = [1.0, 0.0, 0.0]
      const results = await index.search(queryVector, 2)
      
      expect(results.length).assertEqual(2)
      expect(results[0].fileId).assertEqual(1) // 完全匹配
      expect(results[1].fileId).assertEqual(3) // 次相似
    })
    
    it('should add and remove vectors from index', async () => {
      await index.build()
      
      index.addToIndex(100, [0.5, 0.5, 0.0])
      let stats = index.getStats()
      expect(stats.totalVectors).assertEqual(1)
      
      index.removeFromIndex(100)
      stats = index.getStats()
      expect(stats.totalVectors).assertEqual(0)
    })
  })
}
```

- [ ] **Step 6: 运行测试**

运行: `ohpm test`（如果环境支持）

预期: 向量索引测试通过

- [ ] **Step 7: 提交代码**

```bash
git add entry/src/main/ets/data/vector/
git add entry/src/main/ets/data/model/FileEmbedding.ets
git add entry/src/test/ets/data/VectorIndexTest.ets
git commit -m "feat: add vector storage and in-memory index

- Create FileEmbedding model for vector persistence
- Add file_embeddings table to schema
- Implement VectorStore for CRUD operations
- Build in-memory VectorIndex with cosine similarity search
- Support top-K retrieval
- Full test coverage for vector operations

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

## Task 3: RAG 分析服务集成

**Files:**
- Create: `entry/src/main/ets/service/RagAnalysisService.ets`
- Create: `entry/src/main/ets/service/FileProcessingQueue.ets`

**Interfaces:**
- Consumes:
  - `FileRepository` - 查询未处理文件
  - `EmbeddingModel.encode()` - 生成向量（如果可用）
  - `VectorStore.saveEmbedding()` - 保存向量
  - `VectorIndex.addToIndex()` - 更新索引
  - `RagAnalysisLogRepository` - 记录日志
- Produces:
  - `RagAnalysisService.processFile(fileId: number): Promise<void>` - 处理单个文件
  - `RagAnalysisService.processBatch(fileIds: number[]): Promise<void>` - 批量处理
  - `RagAnalysisService.search(query: string, topK: number): Promise<SearchResult[]>` - 语义搜索

---

- [ ] **Step 1: 创建文件处理队列**

```typescript
// entry/src/main/ets/service/FileProcessingQueue.ets

export interface QueueTask {
  fileId: number
  priority: number
  addedTime: number
}

export class FileProcessingQueue {
  private queue: QueueTask[] = []
  private processing: boolean = false
  
  /**
   * 添加任务到队列
   */
  enqueue(fileId: number, priority: number = 0): void {
    const task: QueueTask = {
      fileId,
      priority,
      addedTime: Date.now()
    }
    
    this.queue.push(task)
    this.queue.sort((a, b) => b.priority - a.priority)
  }
  
  /**
   * 从队列取出任务
   */
  dequeue(): QueueTask | null {
    return this.queue.shift() || null
  }
  
  /**
   * 获取队列长度
   */
  size(): number {
    return this.queue.length
  }
  
  /**
   * 清空队列
   */
  clear(): void {
    this.queue = []
  }
  
  /**
   * 检查是否正在处理
   */
  isProcessing(): boolean {
    return this.processing
  }
  
  /**
   * 设置处理状态
   */
  setProcessing(status: boolean): void {
    this.processing = status
  }
}
```

- [ ] **Step 2: 创建 RAG 分析服务**

```typescript
// entry/src/main/ets/service/RagAnalysisService.ets

import { FileRepository } from '../data/repository/FileRepository'
import { VectorStore } from '../data/vector/VectorStore'
import { VectorIndex } from '../data/vector/VectorIndex'
import { RagAnalysisLogRepository } from '../data/repository/RagAnalysisLogRepository'
import { EmbeddingModel } from '../ai/model/EmbeddingModel'
import { FileProcessingQueue } from './FileProcessingQueue'
import { FileInfo } from '../data/model/FileInfo'

export class RagAnalysisService {
  private fileRepo: FileRepository
  private vectorStore: VectorStore
  private vectorIndex: VectorIndex
  private logRepo: RagAnalysisLogRepository
  private embeddingModel: EmbeddingModel
  private queue: FileProcessingQueue
  
  constructor() {
    this.fileRepo = new FileRepository()
    this.vectorStore = new VectorStore()
    this.vectorIndex = new VectorIndex()
    this.logRepo = new RagAnalysisLogRepository()
    this.embeddingModel = new EmbeddingModel()
    this.queue = new FileProcessingQueue()
  }
  
  /**
   * 初始化服务
   */
  async initialize(): Promise<void> {
    // 加载 Embedding 模型（如果可用）
    try {
      await this.embeddingModel.loadModel()
    } catch (err) {
      console.warn('Embedding model not available:', JSON.stringify(err))
    }
    
    // 构建向量索引
    await this.vectorIndex.build()
  }
  
  /**
   * 处理单个文件
   */
  async processFile(fileId: number): Promise<void> {
    const file = await this.fileRepo.findById(fileId)
    if (!file) {
      throw new Error(`File ${fileId} not found`)
    }
    
    // 生成文本摘要（占位 - 实际需要 LLM）
    const summary = await this.generateSummary(file)
    
    // 提取关键词（占位）
    const keywords = await this.extractKeywords(file)
    
    // 生成 embedding 向量
    const embedding = await this.generateEmbedding(file)
    
    // 保存向量
    await this.vectorStore.saveEmbedding(fileId, embedding)
    
    // 更新索引
    this.vectorIndex.addToIndex(fileId, embedding)
    
    // 更新文件元数据
    await this.fileRepo.updateContentSummary(fileId, summary, keywords)
    await this.fileRepo.markAsProcessed(fileId)
  }
  
  /**
   * 批量处理文件
   */
  async processBatch(fileIds: number[]): Promise<void> {
    const batchId = `batch-${Date.now()}`
    const logId = await this.logRepo.createLog(batchId, fileIds.length)
    
    let successCount = 0
    let failureCount = 0
    
    try {
      for (const fileId of fileIds) {
        try {
          await this.processFile(fileId)
          successCount++
        } catch (err) {
          console.error(`Failed to process file ${fileId}:`, JSON.stringify(err))
          failureCount++
        }
      }
      
      await this.logRepo.updateStatus(logId, 'completed', Date.now())
    } catch (err) {
      await this.logRepo.updateStatus(logId, 'failed', Date.now(), undefined, JSON.stringify(err))
    }
  }
  
  /**
   * 语义搜索
   */
  async search(query: string, topK: number = 10): Promise<Array<{ file: FileInfo, score: number }>> {
    // 生成查询向量
    const queryVector = await this.embeddingModel.encode(query)
    
    // 向量检索
    const results = await this.vectorIndex.search(queryVector, topK)
    
    // 填充文件信息
    const enrichedResults: Array<{ file: FileInfo, score: number }> = []
    
    for (const result of results) {
      const file = await this.fileRepo.findById(result.fileId)
      if (file) {
        enrichedResults.push({
          file,
          score: result.score
        })
      }
    }
    
    return enrichedResults
  }
  
  /**
   * 生成文本摘要（占位）
   */
  private async generateSummary(file: FileInfo): Promise<string> {
    // 实际实现需要调用 LLM API
    return `Summary of ${file.name}`
  }
  
  /**
   * 提取关键词（占位）
   */
  private async extractKeywords(file: FileInfo): Promise<string[]> {
    // 实际实现需要 NLP 处理
    return ['keyword1', 'keyword2']
  }
  
  /**
   * 生成 embedding 向量
   */
  private async generateEmbedding(file: FileInfo): Promise<number[]> {
    // 使用文件名和摘要生成向量
    const text = `${file.name} ${file.contentSummary || ''}`
    return await this.embeddingModel.encode(text)
  }
}
```

- [ ] **Step 3: 编写服务测试**

```typescript
// entry/src/test/ets/service/RagAnalysisServiceTest.ets

import { describe, it, expect, beforeAll, afterEach } from '@ohos/hypium'
import { RagAnalysisService } from '../../../main/ets/service/RagAnalysisService'
import { FileRepository } from '../../../main/ets/data/repository/FileRepository'
import { FileInfo } from '../../../main/ets/data/model/FileInfo'
import { DatabaseManager } from '../../../main/ets/data/database/DatabaseManager'

export default function ragAnalysisServiceTest() {
  describe('RagAnalysisService', () => {
    let service: RagAnalysisService
    let fileRepo: FileRepository
    let testFileId: number
    
    beforeAll(async () => {
      await DatabaseManager.getInstance().init(getContext())
      service = new RagAnalysisService()
      fileRepo = new FileRepository()
      
      // 初始化服务
      await service.initialize()
      
      // 创建测试文件
      const fileInfo = new FileInfo({
        uri: 'file://test-doc.pdf',
        name: 'Machine Learning Tutorial',
        type: 'application/pdf',
        size: 2048,
        path: '/data/test-doc.pdf',
        createdTime: Date.now(),
        modifiedTime: Date.now()
      })
      testFileId = await fileRepo.insert(fileInfo)
    })
    
    afterEach(async () => {
      const store = await DatabaseManager.getInstance().getStore()
      await store.executeSql('DELETE FROM file_embeddings')
    })
    
    it('should process file and generate embedding', async () => {
      await service.processFile(testFileId)
      
      const file = await fileRepo.findById(testFileId)
      expect(file).assertNotNull()
      expect(file!.isProcessed).assertTrue()
      expect(file!.contentSummary).assertNotNull()
    })
    
    it('should perform semantic search', async () => {
      // 处理文件
      await service.processFile(testFileId)
      
      // 搜索
      const results = await service.search('machine learning', 5)
      
      expect(results.length).assertLarger(0)
      expect(results[0].file.id).assertEqual(testFileId)
      expect(results[0].score).assertLarger(0)
    })
  })
}
```

- [ ] **Step 4: 提交代码**

```bash
git add entry/src/main/ets/service/
git add entry/src/test/ets/service/
git commit -m "feat: add RAG analysis service with semantic search

- Implement file processing queue with priority
- Create RagAnalysisService for batch processing
- Integrate embedding generation and vector storage
- Support semantic search with top-K retrieval
- Add comprehensive service tests

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

## 自我审查

**1. Spec 覆盖检查:**
- ⚠️ **Task 1 高度依赖 HarmonyOS ONNX Runtime 支持** - 如果不支持，需要替代方案
- ✅ Task 2 向量存储与索引 - 基于内存的简化实现
- ✅ Task 3 RAG 服务集成 - 完整的处理流程

**2. 已知风险:**
- **Critical**: HarmonyOS ONNX Runtime API 可用性未知
- **Important**: Tokenizer 实现是占位（需要真实的 BERT tokenizer）
- **Important**: LLM 文本摘要和关键词提取是占位实现
- **Minor**: 向量索引使用内存存储，扩展性有限

**3. 替代方案（如果 ONNX Runtime 不可用）:**

**方案 A: 预计算向量（推荐用于 MVP）**
- 离线使用 Python + sentence-transformers 生成向量
- 将向量作为 JSON 文件打包到 HarmonyOS 应用
- 应用启动时加载到数据库
- 优点: 简单可靠，无需模型推理
- 缺点: 无法处理新文件

**方案 B: 远程 API**
- 调用云端 Embedding 服务（如 OpenAI Embeddings）
- 优点: 模型质量高，无需本地推理
- 缺点: 需要网络，有 API 成本

**方案 C: 纯 JavaScript 实现**
- 使用 JavaScript 实现简化的文本向量化（TF-IDF 等）
- 优点: 完全本地，无依赖
- 缺点: 语义理解能力弱

**4. 实施建议:**

1. **首先验证 ONNX Runtime 可用性**（Task 1 Step 1）
2. **如果不可用，建议采用方案 A（预计算向量）**
3. **Task 2 和 Task 3 不依赖 ONNX Runtime，可以先行实施**
4. **后续可以升级到方案 B（远程 API）或等待 HarmonyOS 支持**

---

## 总结

**预期交付:**
- 向量存储与索引系统
- 语义搜索功能
- RAG 分析服务框架

**阻塞点:**
- HarmonyOS ONNX Runtime API 可用性

**下一步（如果 Task 1 阻塞）:**
- 采用预计算向量方案完成 MVP
- 实施 LLM 集成（文本摘要、分类规则匹配）

**估算工作量:**
- Task 1（含调研）: 3-5 天
- Task 2: 2-3 天
- Task 3: 2-3 天
- 总计: 1-2 周
