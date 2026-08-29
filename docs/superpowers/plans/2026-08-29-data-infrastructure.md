# 数据基础设施实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为 RAG 文件整理系统建立数据存储基础设施，包括 SQLite 数据库 Schema、向量扩展集成、以及数据访问层。

**Architecture:** 使用 SQLite 作为主数据库，集成 Vector Extension 支持向量存储与检索，采用 Repository 模式封装数据访问逻辑。

**Tech Stack:** ArkTS, SQLite, SQLite Vector Extension (sqlite-vss), @ohos.data.relationalStore

## Global Constraints

- 目标平台: HarmonyOS
- 最低 SDK 版本: 6.1.0(23)
- 数据库版本: SQLite 3.x
- 向量维度: 384 (MiniLM-L6-v2 模型)
- 所有数据库操作必须异步
- 使用鸿蒙官方 relationalStore API
- 文件路径使用 URI 格式
- 时间戳使用 Unix 毫秒时间戳

---

## Task 1: 数据库初始化与 Schema 定义

**Files:**
- Create: `entry/src/main/ets/data/database/DatabaseManager.ets`
- Create: `entry/src/main/ets/data/database/DatabaseSchema.ets`
- Create: `entry/src/main/ets/data/database/DatabaseConfig.ets`

**Interfaces:**
- Consumes: `@ohos.data.relationalStore` (鸿蒙系统 API)
- Produces: 
  - `DatabaseManager.getInstance(): DatabaseManager` - 数据库单例
  - `DatabaseManager.getStore(): Promise<relationalStore.RdbStore>` - 获取数据库实例

---

- [ ] **Step 1: 创建数据库配置文件**

```typescript
// entry/src/main/ets/data/database/DatabaseConfig.ets

export class DatabaseConfig {
  static readonly DB_NAME: string = 'shixu_rag.db'
  static readonly DB_VERSION: number = 1
  static readonly VECTOR_DIMENSION: number = 384
  
  static readonly TABLE_FILES: string = 'files'
  static readonly TABLE_COLLECTIONS: string = 'collections'
  static readonly TABLE_FILE_COLLECTION_REFS: string = 'file_collection_refs'
  static readonly TABLE_VECTOR_STORAGE_TIERS: string = 'vector_storage_tiers'
  static readonly TABLE_RAG_ANALYSIS_LOGS: string = 'rag_analysis_logs'
  
  // 虚拟表（向量扩展）
  static readonly TABLE_FILE_EMBEDDINGS: string = 'file_embeddings'
  static readonly TABLE_KEYWORD_EMBEDDINGS: string = 'keyword_embeddings'
}
```

- [ ] **Step 2: 创建 Schema 定义**

```typescript
// entry/src/main/ets/data/database/DatabaseSchema.ets

export class DatabaseSchema {
  /**
   * 获取所有建表 SQL 语句
   */
  static getCreateTableSQLs(): string[] {
    return [
      this.createFilesTable(),
      this.createCollectionsTable(),
      this.createFileCollectionRefsTable(),
      this.createVectorStorageTiersTable(),
      this.createRagAnalysisLogsTable()
    ]
  }
  
  private static createFilesTable(): string {
    return `
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
      )
    `
  }
  
  private static createCollectionsTable(): string {
    return `
      CREATE TABLE IF NOT EXISTS collections (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        icon TEXT,
        color TEXT,
        description TEXT,
        rules TEXT NOT NULL,
        created_time INTEGER NOT NULL,
        is_preset INTEGER DEFAULT 0
      )
    `
  }
  
  private static createFileCollectionRefsTable(): string {
    return `
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
      )
    `
  }
  
  private static createVectorStorageTiersTable(): string {
    return `
      CREATE TABLE IF NOT EXISTS vector_storage_tiers (
        file_id INTEGER PRIMARY KEY,
        tier TEXT NOT NULL,
        last_accessed INTEGER NOT NULL,
        access_count INTEGER DEFAULT 1,
        FOREIGN KEY (file_id) REFERENCES files(id)
      )
    `
  }
  
  private static createRagAnalysisLogsTable(): string {
    return `
      CREATE TABLE IF NOT EXISTS rag_analysis_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        batch_id TEXT NOT NULL,
        file_count INTEGER NOT NULL,
        start_time INTEGER NOT NULL,
        end_time INTEGER,
        llm_tokens_used INTEGER,
        status TEXT,
        error_message TEXT
      )
    `
  }
  
  /**
   * 获取创建索引的 SQL 语句
   */
  static getCreateIndexSQLs(): string[] {
    return [
      'CREATE INDEX IF NOT EXISTS idx_files_uri ON files(uri)',
      'CREATE INDEX IF NOT EXISTS idx_files_is_processed ON files(is_processed)',
      'CREATE INDEX IF NOT EXISTS idx_file_collection_refs_file_id ON file_collection_refs(file_id)',
      'CREATE INDEX IF NOT EXISTS idx_file_collection_refs_collection_id ON file_collection_refs(collection_id)',
      'CREATE INDEX IF NOT EXISTS idx_vector_storage_tiers_tier ON vector_storage_tiers(tier)'
    ]
  }
}
```

- [ ] **Step 3: 创建数据库管理器**

```typescript
// entry/src/main/ets/data/database/DatabaseManager.ets

import relationalStore from '@ohos.data.relationalStore'
import { DatabaseConfig } from './DatabaseConfig'
import { DatabaseSchema } from './DatabaseSchema'
import common from '@ohos.app.ability.common'

export class DatabaseManager {
  private static instance: DatabaseManager
  private store: relationalStore.RdbStore | null = null
  private initPromise: Promise<void> | null = null
  
  private constructor() {}
  
  static getInstance(): DatabaseManager {
    if (!DatabaseManager.instance) {
      DatabaseManager.instance = new DatabaseManager()
    }
    return DatabaseManager.instance
  }
  
  /**
   * 初始化数据库
   */
  async init(context: common.UIAbilityContext): Promise<void> {
    if (this.initPromise) {
      return this.initPromise
    }
    
    this.initPromise = this.doInit(context)
    return this.initPromise
  }
  
  private async doInit(context: common.UIAbilityContext): Promise<void> {
    const config: relationalStore.StoreConfig = {
      name: DatabaseConfig.DB_NAME,
      securityLevel: relationalStore.SecurityLevel.S1
    }
    
    this.store = await relationalStore.getRdbStore(context, config)
    
    // 创建表
    const createTableSQLs = DatabaseSchema.getCreateTableSQLs()
    for (const sql of createTableSQLs) {
      await this.store.executeSql(sql)
    }
    
    // 创建索引
    const createIndexSQLs = DatabaseSchema.getCreateIndexSQLs()
    for (const sql of createIndexSQLs) {
      await this.store.executeSql(sql)
    }
  }
  
  /**
   * 获取数据库实例
   */
  async getStore(): Promise<relationalStore.RdbStore> {
    if (!this.store) {
      throw new Error('Database not initialized. Call init() first.')
    }
    return this.store
  }
  
  /**
   * 关闭数据库
   */
  async close(): Promise<void> {
    if (this.store) {
      await this.store.close()
      this.store = null
      this.initPromise = null
    }
  }
}
```

- [ ] **Step 4: 在 EntryAbility 中初始化数据库**

修改 `entry/src/main/ets/entryability/EntryAbility.ets`:

```typescript
import { DatabaseManager } from '../data/database/DatabaseManager'

export default class EntryAbility extends UIAbility {
  async onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): Promise<void> {
    // 初始化数据库
    try {
      await DatabaseManager.getInstance().init(this.context)
      console.info('[EntryAbility] Database initialized successfully')
    } catch (err) {
      console.error('[EntryAbility] Database initialization failed:', JSON.stringify(err))
    }
    
    // ... 其他初始化代码
  }
  
  onDestroy(): void {
    // 关闭数据库
    DatabaseManager.getInstance().close()
  }
}
```

- [ ] **Step 5: 验证数据库初始化**

创建简单测试验证数据库是否成功创建：

```typescript
// entry/src/test/ets/data/DatabaseManagerTest.ets

import { describe, it, expect } from '@ohos/hypium'
import { DatabaseManager } from '../../../main/ets/data/database/DatabaseManager'

export default function databaseManagerTest() {
  describe('DatabaseManager', () => {
    it('should initialize database successfully', async () => {
      const dbManager = DatabaseManager.getInstance()
      const store = await dbManager.getStore()
      expect(store).assertNotNull()
    })
    
    it('should create files table', async () => {
      const dbManager = DatabaseManager.getInstance()
      const store = await dbManager.getStore()
      
      // 查询表是否存在
      const sql = "SELECT name FROM sqlite_master WHERE type='table' AND name='files'"
      const resultSet = await store.querySql(sql)
      const exists = resultSet.goToFirstRow()
      resultSet.close()
      
      expect(exists).assertTrue()
    })
  })
}
```

- [ ] **Step 6: 运行测试**

运行: `ohpm test`

预期: 所有测试通过，数据库成功创建

- [ ] **Step 7: 提交代码**

```bash
git add entry/src/main/ets/data/database/
git add entry/src/main/ets/entryability/EntryAbility.ets
git add entry/src/test/ets/data/DatabaseManagerTest.ets
git commit -m "feat: add database initialization and schema

- Create DatabaseManager singleton with relationalStore
- Define schema for files, collections, refs, tiers, logs tables
- Add indexes for common query patterns
- Initialize database in EntryAbility onCreate
- Add unit tests for database creation

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

## Task 2: 文件数据访问层 (FileRepository)

**Files:**
- Create: `entry/src/main/ets/data/model/FileInfo.ets`
- Create: `entry/src/main/ets/data/repository/FileRepository.ets`
- Test: `entry/src/test/ets/data/FileRepositoryTest.ets`

**Interfaces:**
- Consumes: `DatabaseManager.getStore(): Promise<relationalStore.RdbStore>`
- Produces:
  - `FileRepository.insert(fileInfo: FileInfo): Promise<number>` - 插入文件，返回 ID
  - `FileRepository.findByUri(uri: string): Promise<FileInfo | null>` - 根据 URI 查询
  - `FileRepository.findUnprocessed(limit?: number): Promise<FileInfo[]>` - 查询未处理文件
  - `FileRepository.markAsProcessed(fileId: number): Promise<void>` - 标记为已处理
  - `FileRepository.updateContentSummary(fileId: number, summary: string, keywords: string[]): Promise<void>` - 更新内容摘要

---

- [ ] **Step 1: 创建 FileInfo 数据模型**

```typescript
// entry/src/main/ets/data/model/FileInfo.ets

export class FileInfo {
  id?: number
  uri: string
  name: string
  type: string
  size: number
  path: string
  createdTime: number
  modifiedTime: number
  contentHash?: string
  isProcessed: boolean = false
  processedTime?: number
  contentSummary?: string
  extractedKeywords?: string[]
  
  constructor(init?: Partial<FileInfo>) {
    Object.assign(this, init)
  }
  
  /**
   * 从数据库行转换为 FileInfo
   */
  static fromRow(row: any): FileInfo {
    return new FileInfo({
      id: row.id,
      uri: row.uri,
      name: row.name,
      type: row.type,
      size: row.size,
      path: row.path,
      createdTime: row.created_time,
      modifiedTime: row.modified_time,
      contentHash: row.content_hash,
      isProcessed: row.is_processed === 1,
      processedTime: row.processed_time,
      contentSummary: row.content_summary,
      extractedKeywords: row.extracted_keywords ? JSON.parse(row.extracted_keywords) : []
    })
  }
  
  /**
   * 转换为数据库行对象
   */
  toValuesBucket(): Record<string, any> {
    const values: Record<string, any> = {
      uri: this.uri,
      name: this.name,
      type: this.type,
      size: this.size,
      path: this.path,
      created_time: this.createdTime,
      modified_time: this.modifiedTime,
      is_processed: this.isProcessed ? 1 : 0
    }
    
    if (this.contentHash) values.content_hash = this.contentHash
    if (this.processedTime) values.processed_time = this.processedTime
    if (this.contentSummary) values.content_summary = this.contentSummary
    if (this.extractedKeywords) values.extracted_keywords = JSON.stringify(this.extractedKeywords)
    
    return values
  }
}
```

- [ ] **Step 2: 编写 FileInfo 模型测试**

```typescript
// entry/src/test/ets/data/FileInfoTest.ets

import { describe, it, expect } from '@ohos/hypium'
import { FileInfo } from '../../../main/ets/data/model/FileInfo'

export default function fileInfoTest() {
  describe('FileInfo', () => {
    it('should create FileInfo from constructor', () => {
      const fileInfo = new FileInfo({
        uri: 'file://test.pdf',
        name: 'test.pdf',
        type: 'application/pdf',
        size: 1024,
        path: '/data/storage/test.pdf',
        createdTime: Date.now(),
        modifiedTime: Date.now()
      })
      
      expect(fileInfo.name).assertEqual('test.pdf')
      expect(fileInfo.isProcessed).assertFalse()
    })
    
    it('should convert to ValuesBucket correctly', () => {
      const fileInfo = new FileInfo({
        uri: 'file://test.pdf',
        name: 'test.pdf',
        type: 'application/pdf',
        size: 1024,
        path: '/data/storage/test.pdf',
        createdTime: 123456789,
        modifiedTime: 123456789
      })
      
      const bucket = fileInfo.toValuesBucket()
      expect(bucket.uri).assertEqual('file://test.pdf')
      expect(bucket.is_processed).assertEqual(0)
      expect(bucket.created_time).assertEqual(123456789)
    })
  })
}
```

- [ ] **Step 3: 运行模型测试**

运行: `ohpm test`

预期: FileInfo 模型测试通过

- [ ] **Step 4: 创建 FileRepository**

```typescript
// entry/src/main/ets/data/repository/FileRepository.ets

import relationalStore from '@ohos.data.relationalStore'
import { DatabaseManager } from '../database/DatabaseManager'
import { DatabaseConfig } from '../database/DatabaseConfig'
import { FileInfo } from '../model/FileInfo'

export class FileRepository {
  private async getStore(): Promise<relationalStore.RdbStore> {
    return await DatabaseManager.getInstance().getStore()
  }
  
  /**
   * 插入文件记录
   */
  async insert(fileInfo: FileInfo): Promise<number> {
    const store = await this.getStore()
    const values = fileInfo.toValuesBucket()
    return await store.insert(DatabaseConfig.TABLE_FILES, values)
  }
  
  /**
   * 根据 URI 查询文件
   */
  async findByUri(uri: string): Promise<FileInfo | null> {
    const store = await this.getStore()
    const predicates = new relationalStore.RdbPredicates(DatabaseConfig.TABLE_FILES)
    predicates.equalTo('uri', uri)
    
    const resultSet = await store.query(predicates)
    
    if (resultSet.goToFirstRow()) {
      const rowData = this.resultSetToObject(resultSet)
      resultSet.close()
      return FileInfo.fromRow(rowData)
    }
    
    resultSet.close()
    return null
  }
  
  /**
   * 查询未处理的文件
   */
  async findUnprocessed(limit: number = 100): Promise<FileInfo[]> {
    const store = await this.getStore()
    const predicates = new relationalStore.RdbPredicates(DatabaseConfig.TABLE_FILES)
    predicates.equalTo('is_processed', 0)
    predicates.orderByDesc('created_time')
    predicates.limit(limit)
    
    const resultSet = await store.query(predicates)
    const files: FileInfo[] = []
    
    while (resultSet.goToNextRow()) {
      const rowData = this.resultSetToObject(resultSet)
      files.push(FileInfo.fromRow(rowData))
    }
    
    resultSet.close()
    return files
  }
  
  /**
   * 标记文件为已处理
   */
  async markAsProcessed(fileId: number): Promise<void> {
    const store = await this.getStore()
    const predicates = new relationalStore.RdbPredicates(DatabaseConfig.TABLE_FILES)
    predicates.equalTo('id', fileId)
    
    const values = {
      is_processed: 1,
      processed_time: Date.now()
    }
    
    await store.update(values, predicates)
  }
  
  /**
   * 更新文件内容摘要和关键词
   */
  async updateContentSummary(fileId: number, summary: string, keywords: string[]): Promise<void> {
    const store = await this.getStore()
    const predicates = new relationalStore.RdbPredicates(DatabaseConfig.TABLE_FILES)
    predicates.equalTo('id', fileId)
    
    const values = {
      content_summary: summary,
      extracted_keywords: JSON.stringify(keywords)
    }
    
    await store.update(values, predicates)
  }
  
  /**
   * 根据 ID 查询文件
   */
  async findById(id: number): Promise<FileInfo | null> {
    const store = await this.getStore()
    const predicates = new relationalStore.RdbPredicates(DatabaseConfig.TABLE_FILES)
    predicates.equalTo('id', id)
    
    const resultSet = await store.query(predicates)
    
    if (resultSet.goToFirstRow()) {
      const rowData = this.resultSetToObject(resultSet)
      resultSet.close()
      return FileInfo.fromRow(rowData)
    }
    
    resultSet.close()
    return null
  }
  
  /**
   * 删除文件记录
   */
  async deleteById(id: number): Promise<void> {
    const store = await this.getStore()
    const predicates = new relationalStore.RdbPredicates(DatabaseConfig.TABLE_FILES)
    predicates.equalTo('id', id)
    await store.delete(predicates)
  }
  
  /**
   * 获取未处理文件数量
   */
  async countUnprocessed(): Promise<number> {
    const store = await this.getStore()
    const sql = `SELECT COUNT(*) as count FROM ${DatabaseConfig.TABLE_FILES} WHERE is_processed = 0`
    const resultSet = await store.querySql(sql)
    
    if (resultSet.goToFirstRow()) {
      const count = resultSet.getLong(0)
      resultSet.close()
      return count
    }
    
    resultSet.close()
    return 0
  }
  
  /**
   * 辅助方法：将 ResultSet 当前行转换为对象
   */
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
        case relationalStore.ColumnType.TYPE_FLOAT:
          row[columnName] = resultSet.getDouble(i)
          break
        case relationalStore.ColumnType.TYPE_STRING:
          row[columnName] = resultSet.getString(i)
          break
        case relationalStore.ColumnType.TYPE_BLOB:
          row[columnName] = resultSet.getBlob(i)
          break
        default:
          row[columnName] = null
      }
    }
    
    return row
  }
}
```

- [ ] **Step 5: 编写 FileRepository 测试**

```typescript
// entry/src/test/ets/data/FileRepositoryTest.ets

import { describe, it, expect, beforeAll, afterEach } from '@ohos/hypium'
import { FileRepository } from '../../../main/ets/data/repository/FileRepository'
import { FileInfo } from '../../../main/ets/data/model/FileInfo'
import { DatabaseManager } from '../../../main/ets/data/database/DatabaseManager'

export default function fileRepositoryTest() {
  describe('FileRepository', () => {
    let repository: FileRepository
    
    beforeAll(async () => {
      // 确保数据库已初始化
      await DatabaseManager.getInstance().init(getContext())
      repository = new FileRepository()
    })
    
    afterEach(async () => {
      // 清理测试数据
      const store = await DatabaseManager.getInstance().getStore()
      await store.executeSql('DELETE FROM files')
    })
    
    it('should insert file and return id', async () => {
      const fileInfo = new FileInfo({
        uri: 'file://test.pdf',
        name: 'test.pdf',
        type: 'application/pdf',
        size: 1024,
        path: '/data/test.pdf',
        createdTime: Date.now(),
        modifiedTime: Date.now()
      })
      
      const fileId = await repository.insert(fileInfo)
      expect(fileId).assertLarger(0)
    })
    
    it('should find file by uri', async () => {
      const fileInfo = new FileInfo({
        uri: 'file://test.pdf',
        name: 'test.pdf',
        type: 'application/pdf',
        size: 1024,
        path: '/data/test.pdf',
        createdTime: Date.now(),
        modifiedTime: Date.now()
      })
      
      await repository.insert(fileInfo)
      const found = await repository.findByUri('file://test.pdf')
      
      expect(found).assertNotNull()
      expect(found!.name).assertEqual('test.pdf')
    })
    
    it('should find unprocessed files', async () => {
      const file1 = new FileInfo({
        uri: 'file://test1.pdf',
        name: 'test1.pdf',
        type: 'application/pdf',
        size: 1024,
        path: '/data/test1.pdf',
        createdTime: Date.now(),
        modifiedTime: Date.now()
      })
      
      const file2 = new FileInfo({
        uri: 'file://test2.pdf',
        name: 'test2.pdf',
        type: 'application/pdf',
        size: 2048,
        path: '/data/test2.pdf',
        createdTime: Date.now(),
        modifiedTime: Date.now()
      })
      
      await repository.insert(file1)
      await repository.insert(file2)
      
      const unprocessed = await repository.findUnprocessed()
      expect(unprocessed.length).assertEqual(2)
    })
    
    it('should mark file as processed', async () => {
      const fileInfo = new FileInfo({
        uri: 'file://test.pdf',
        name: 'test.pdf',
        type: 'application/pdf',
        size: 1024,
        path: '/data/test.pdf',
        createdTime: Date.now(),
        modifiedTime: Date.now()
      })
      
      const fileId = await repository.insert(fileInfo)
      await repository.markAsProcessed(fileId)
      
      const updated = await repository.findById(fileId)
      expect(updated!.isProcessed).assertTrue()
      expect(updated!.processedTime).assertLarger(0)
    })
    
    it('should update content summary', async () => {
      const fileInfo = new FileInfo({
        uri: 'file://test.pdf',
        name: 'test.pdf',
        type: 'application/pdf',
        size: 1024,
        path: '/data/test.pdf',
        createdTime: Date.now(),
        modifiedTime: Date.now()
      })
      
      const fileId = await repository.insert(fileInfo)
      await repository.updateContentSummary(fileId, 'This is a test document', ['test', 'document'])
      
      const updated = await repository.findById(fileId)
      expect(updated!.contentSummary).assertEqual('This is a test document')
      expect(updated!.extractedKeywords!.length).assertEqual(2)
    })
    
    it('should count unprocessed files', async () => {
      const file1 = new FileInfo({
        uri: 'file://test1.pdf',
        name: 'test1.pdf',
        type: 'application/pdf',
        size: 1024,
        path: '/data/test1.pdf',
        createdTime: Date.now(),
        modifiedTime: Date.now()
      })
      
      await repository.insert(file1)
      const count = await repository.countUnprocessed()
      expect(count).assertEqual(1)
    })
  })
}
```

- [ ] **Step 6: 运行测试**

运行: `ohpm test`

预期: 所有 FileRepository 测试通过

- [ ] **Step 7: 提交代码**

```bash
git add entry/src/main/ets/data/model/FileInfo.ets
git add entry/src/main/ets/data/repository/FileRepository.ets
git add entry/src/test/ets/data/FileInfoTest.ets
git add entry/src/test/ets/data/FileRepositoryTest.ets
git commit -m "feat: add FileRepository data access layer

- Create FileInfo model with toValuesBucket/fromRow converters
- Implement FileRepository CRUD operations
- Support unprocessed file queries
- Add content summary update
- Full test coverage for repository operations

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

## Task 3: 收纳箱数据访问层 (CollectionRepository)

**Files:**
- Create: `entry/src/main/ets/data/model/Collection.ets`
- Create: `entry/src/main/ets/data/model/CollectionRule.ets`
- Create: `entry/src/main/ets/data/repository/CollectionRepository.ets`
- Test: `entry/src/test/ets/data/CollectionRepositoryTest.ets`

**Interfaces:**
- Consumes: `DatabaseManager.getStore(): Promise<relationalStore.RdbStore>`
- Produces:
  - `CollectionRepository.insert(collection: Collection): Promise<number>` - 插入收纳箱
  - `CollectionRepository.findAll(): Promise<Collection[]>` - 查询所有收纳箱
  - `CollectionRepository.findById(id: number): Promise<Collection | null>` - 根据 ID 查询
  - `CollectionRepository.update(collection: Collection): Promise<void>` - 更新收纳箱
  - `CollectionRepository.delete(id: number): Promise<void>` - 删除收纳箱

---

- [ ] **Step 1: 创建 CollectionRule 模型**

```typescript
// entry/src/main/ets/data/model/CollectionRule.ets

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

export interface RuleCondition {
  type: ConditionType
  operator: OperatorType
  value: string | number | string[]
}

export class CollectionRule {
  id: number = 0
  collectionId: number = 0
  priority: number = 0
  conditions: RuleCondition[] = []
  enabled: boolean = true
  createdTime: number = Date.now()
  
  constructor(init?: Partial<CollectionRule>) {
    Object.assign(this, init)
  }
}
```

- [ ] **Step 2: 创建 Collection 模型**

```typescript
// entry/src/main/ets/data/model/Collection.ets

import { CollectionRule } from './CollectionRule'

export class Collection {
  id?: number
  name: string
  icon?: string
  color?: string
  description?: string
  rules: CollectionRule[] = []
  createdTime: number = Date.now()
  isPreset: boolean = false
  
  constructor(init?: Partial<Collection>) {
    Object.assign(this, init)
  }
  
  /**
   * 从数据库行转换为 Collection
   */
  static fromRow(row: any): Collection {
    return new Collection({
      id: row.id,
      name: row.name,
      icon: row.icon,
      color: row.color,
      description: row.description,
      rules: row.rules ? JSON.parse(row.rules) : [],
      createdTime: row.created_time,
      isPreset: row.is_preset === 1
    })
  }
  
  /**
   * 转换为数据库行对象
   */
  toValuesBucket(): Record<string, any> {
    const values: Record<string, any> = {
      name: this.name,
      rules: JSON.stringify(this.rules),
      created_time: this.createdTime,
      is_preset: this.isPreset ? 1 : 0
    }
    
    if (this.icon) values.icon = this.icon
    if (this.color) values.color = this.color
    if (this.description) values.description = this.description
    
    return values
  }
}
```

- [ ] **Step 3: 创建 CollectionRepository**

```typescript
// entry/src/main/ets/data/repository/CollectionRepository.ets

import relationalStore from '@ohos.data.relationalStore'
import { DatabaseManager } from '../database/DatabaseManager'
import { DatabaseConfig } from '../database/DatabaseConfig'
import { Collection } from '../model/Collection'

export class CollectionRepository {
  private async getStore(): Promise<relationalStore.RdbStore> {
    return await DatabaseManager.getInstance().getStore()
  }
  
  /**
   * 插入收纳箱
   */
  async insert(collection: Collection): Promise<number> {
    const store = await this.getStore()
    const values = collection.toValuesBucket()
    return await store.insert(DatabaseConfig.TABLE_COLLECTIONS, values)
  }
  
  /**
   * 查询所有收纳箱
   */
  async findAll(): Promise<Collection[]> {
    const store = await this.getStore()
    const predicates = new relationalStore.RdbPredicates(DatabaseConfig.TABLE_COLLECTIONS)
    predicates.orderByAsc('created_time')
    
    const resultSet = await store.query(predicates)
    const collections: Collection[] = []
    
    while (resultSet.goToNextRow()) {
      const rowData = this.resultSetToObject(resultSet)
      collections.push(Collection.fromRow(rowData))
    }
    
    resultSet.close()
    return collections
  }
  
  /**
   * 根据 ID 查询收纳箱
   */
  async findById(id: number): Promise<Collection | null> {
    const store = await this.getStore()
    const predicates = new relationalStore.RdbPredicates(DatabaseConfig.TABLE_COLLECTIONS)
    predicates.equalTo('id', id)
    
    const resultSet = await store.query(predicates)
    
    if (resultSet.goToFirstRow()) {
      const rowData = this.resultSetToObject(resultSet)
      resultSet.close()
      return Collection.fromRow(rowData)
    }
    
    resultSet.close()
    return null
  }
  
  /**
   * 更新收纳箱
   */
  async update(collection: Collection): Promise<void> {
    if (!collection.id) {
      throw new Error('Collection id is required for update')
    }
    
    const store = await this.getStore()
    const predicates = new relationalStore.RdbPredicates(DatabaseConfig.TABLE_COLLECTIONS)
    predicates.equalTo('id', collection.id)
    
    const values = collection.toValuesBucket()
    await store.update(values, predicates)
  }
  
  /**
   * 删除收纳箱
   */
  async delete(id: number): Promise<void> {
    const store = await this.getStore()
    const predicates = new relationalStore.RdbPredicates(DatabaseConfig.TABLE_COLLECTIONS)
    predicates.equalTo('id', id)
    await store.delete(predicates)
  }
  
  /**
   * 查询预设收纳箱
   */
  async findPresets(): Promise<Collection[]> {
    const store = await this.getStore()
    const predicates = new relationalStore.RdbPredicates(DatabaseConfig.TABLE_COLLECTIONS)
    predicates.equalTo('is_preset', 1)
    
    const resultSet = await store.query(predicates)
    const collections: Collection[] = []
    
    while (resultSet.goToNextRow()) {
      const rowData = this.resultSetToObject(resultSet)
      collections.push(Collection.fromRow(rowData))
    }
    
    resultSet.close()
    return collections
  }
  
  /**
   * 辅助方法：将 ResultSet 当前行转换为对象
   */
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
        case relationalStore.ColumnType.TYPE_FLOAT:
          row[columnName] = resultSet.getDouble(i)
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

- [ ] **Step 4: 编写 CollectionRepository 测试**

```typescript
// entry/src/test/ets/data/CollectionRepositoryTest.ets

import { describe, it, expect, beforeAll, afterEach } from '@ohos/hypium'
import { CollectionRepository } from '../../../main/ets/data/repository/CollectionRepository'
import { Collection } from '../../../main/ets/data/model/Collection'
import { CollectionRule, ConditionType, OperatorType } from '../../../main/ets/data/model/CollectionRule'
import { DatabaseManager } from '../../../main/ets/data/database/DatabaseManager'

export default function collectionRepositoryTest() {
  describe('CollectionRepository', () => {
    let repository: CollectionRepository
    
    beforeAll(async () => {
      await DatabaseManager.getInstance().init(getContext())
      repository = new CollectionRepository()
    })
    
    afterEach(async () => {
      const store = await DatabaseManager.getInstance().getStore()
      await store.executeSql('DELETE FROM collections')
    })
    
    it('should insert collection with rules', async () => {
      const rule: CollectionRule = new CollectionRule({
        priority: 1,
        conditions: [
          {
            type: ConditionType.FILE_TYPE,
            operator: OperatorType.EQUALS,
            value: 'pdf'
          }
        ]
      })
      
      const collection = new Collection({
        name: 'PDF Documents',
        icon: 'ic_pdf',
        color: '#FF0000',
        rules: [rule]
      })
      
      const collectionId = await repository.insert(collection)
      expect(collectionId).assertLarger(0)
    })
    
    it('should find all collections', async () => {
      const collection1 = new Collection({
        name: 'Collection 1',
        rules: []
      })
      
      const collection2 = new Collection({
        name: 'Collection 2',
        rules: []
      })
      
      await repository.insert(collection1)
      await repository.insert(collection2)
      
      const all = await repository.findAll()
      expect(all.length).assertEqual(2)
    })
    
    it('should find collection by id', async () => {
      const collection = new Collection({
        name: 'Test Collection',
        description: 'Test description',
        rules: []
      })
      
      const collectionId = await repository.insert(collection)
      const found = await repository.findById(collectionId)
      
      expect(found).assertNotNull()
      expect(found!.name).assertEqual('Test Collection')
      expect(found!.description).assertEqual('Test description')
    })
    
    it('should update collection', async () => {
      const collection = new Collection({
        name: 'Original Name',
        rules: []
      })
      
      const collectionId = await repository.insert(collection)
      
      const toUpdate = await repository.findById(collectionId)
      toUpdate!.name = 'Updated Name'
      toUpdate!.color = '#00FF00'
      await repository.update(toUpdate!)
      
      const updated = await repository.findById(collectionId)
      expect(updated!.name).assertEqual('Updated Name')
      expect(updated!.color).assertEqual('#00FF00')
    })
    
    it('should delete collection', async () => {
      const collection = new Collection({
        name: 'To Delete',
        rules: []
      })
      
      const collectionId = await repository.insert(collection)
      await repository.delete(collectionId)
      
      const deleted = await repository.findById(collectionId)
      expect(deleted).assertNull()
    })
    
    it('should find preset collections', async () => {
      const preset = new Collection({
        name: 'Preset Collection',
        isPreset: true,
        rules: []
      })
      
      const custom = new Collection({
        name: 'Custom Collection',
        isPreset: false,
        rules: []
      })
      
      await repository.insert(preset)
      await repository.insert(custom)
      
      const presets = await repository.findPresets()
      expect(presets.length).assertEqual(1)
      expect(presets[0].name).assertEqual('Preset Collection')
    })
  })
}
```

- [ ] **Step 5: 运行测试**

运行: `ohpm test`

预期: 所有 CollectionRepository 测试通过

- [ ] **Step 6: 提交代码**

```bash
git add entry/src/main/ets/data/model/Collection.ets
git add entry/src/main/ets/data/model/CollectionRule.ets
git add entry/src/main/ets/data/repository/CollectionRepository.ets
git add entry/src/test/ets/data/CollectionRepositoryTest.ets
git commit -m "feat: add CollectionRepository data access layer

- Create Collection and CollectionRule models
- Define ConditionType and OperatorType enums
- Implement CollectionRepository CRUD operations
- Support preset collections query
- Full test coverage for collection operations

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

## Task 4: 文件-收纳箱关联管理 (FileCollectionRefRepository)

**Files:**
- Create: `entry/src/main/ets/data/model/FileCollectionRef.ets`
- Create: `entry/src/main/ets/data/repository/FileCollectionRefRepository.ets`
- Test: `entry/src/test/ets/data/FileCollectionRefRepositoryTest.ets`

**Interfaces:**
- Consumes: `DatabaseManager.getStore(): Promise<relationalStore.RdbStore>`
- Produces:
  - `FileCollectionRefRepository.addRef(fileId: number, collectionId: number, confidence: number, createdBy: 'llm' | 'manual'): Promise<number>` - 添加关联
  - `FileCollectionRefRepository.findByFileId(fileId: number): Promise<FileCollectionRef[]>` - 查询文件的所有关联
  - `FileCollectionRefRepository.findByCollectionId(collectionId: number): Promise<FileCollectionRef[]>` - 查询收纳箱的所有文件
  - `FileCollectionRefRepository.removeRef(fileId: number, collectionId: number): Promise<void>` - 移除关联

---

- [ ] **Step 1: 创建 FileCollectionRef 模型**

```typescript
// entry/src/main/ets/data/model/FileCollectionRef.ets

export type RefType = 'link' | 'physical'
export type CreatedBy = 'llm' | 'manual'

export class FileCollectionRef {
  id?: number
  fileId: number
  collectionId: number
  refType: RefType = 'link'
  confidence?: number
  createdTime: number = Date.now()
  createdBy: CreatedBy = 'llm'
  
  constructor(init?: Partial<FileCollectionRef>) {
    Object.assign(this, init)
  }
  
  /**
   * 从数据库行转换
   */
  static fromRow(row: any): FileCollectionRef {
    return new FileCollectionRef({
      id: row.id,
      fileId: row.file_id,
      collectionId: row.collection_id,
      refType: row.ref_type as RefType,
      confidence: row.confidence,
      createdTime: row.created_time,
      createdBy: row.created_by as CreatedBy
    })
  }
  
  /**
   * 转换为数据库行对象
   */
  toValuesBucket(): Record<string, any> {
    const values: Record<string, any> = {
      file_id: this.fileId,
      collection_id: this.collectionId,
      ref_type: this.refType,
      created_time: this.createdTime,
      created_by: this.createdBy
    }
    
    if (this.confidence !== undefined) {
      values.confidence = this.confidence
    }
    
    return values
  }
}
```

- [ ] **Step 2: 创建 FileCollectionRefRepository**

```typescript
// entry/src/main/ets/data/repository/FileCollectionRefRepository.ets

import relationalStore from '@ohos.data.relationalStore'
import { DatabaseManager } from '../database/DatabaseManager'
import { DatabaseConfig } from '../database/DatabaseConfig'
import { FileCollectionRef, CreatedBy } from '../model/FileCollectionRef'

export class FileCollectionRefRepository {
  private async getStore(): Promise<relationalStore.RdbStore> {
    return await DatabaseManager.getInstance().getStore()
  }
  
  /**
   * 添加文件和收纳箱的关联
   */
  async addRef(
    fileId: number, 
    collectionId: number, 
    confidence: number = 1.0, 
    createdBy: CreatedBy = 'llm'
  ): Promise<number> {
    const ref = new FileCollectionRef({
      fileId,
      collectionId,
      confidence,
      createdBy
    })
    
    const store = await this.getStore()
    const values = ref.toValuesBucket()
    return await store.insert(DatabaseConfig.TABLE_FILE_COLLECTION_REFS, values)
  }
  
  /**
   * 根据文件 ID 查询所有关联
   */
  async findByFileId(fileId: number): Promise<FileCollectionRef[]> {
    const store = await this.getStore()
    const predicates = new relationalStore.RdbPredicates(DatabaseConfig.TABLE_FILE_COLLECTION_REFS)
    predicates.equalTo('file_id', fileId)
    
    const resultSet = await store.query(predicates)
    const refs: FileCollectionRef[] = []
    
    while (resultSet.goToNextRow()) {
      const rowData = this.resultSetToObject(resultSet)
      refs.push(FileCollectionRef.fromRow(rowData))
    }
    
    resultSet.close()
    return refs
  }
  
  /**
   * 根据收纳箱 ID 查询所有关联
   */
  async findByCollectionId(collectionId: number): Promise<FileCollectionRef[]> {
    const store = await this.getStore()
    const predicates = new relationalStore.RdbPredicates(DatabaseConfig.TABLE_FILE_COLLECTION_REFS)
    predicates.equalTo('collection_id', collectionId)
    
    const resultSet = await store.query(predicates)
    const refs: FileCollectionRef[] = []
    
    while (resultSet.goToNextRow()) {
      const rowData = this.resultSetToObject(resultSet)
      refs.push(FileCollectionRef.fromRow(rowData))
    }
    
    resultSet.close()
    return refs
  }
  
  /**
   * 移除文件和收纳箱的关联
   */
  async removeRef(fileId: number, collectionId: number): Promise<void> {
    const store = await this.getStore()
    const predicates = new relationalStore.RdbPredicates(DatabaseConfig.TABLE_FILE_COLLECTION_REFS)
    predicates.equalTo('file_id', fileId)
    predicates.and()
    predicates.equalTo('collection_id', collectionId)
    
    await store.delete(predicates)
  }
  
  /**
   * 检查关联是否存在
   */
  async exists(fileId: number, collectionId: number): Promise<boolean> {
    const store = await this.getStore()
    const predicates = new relationalStore.RdbPredicates(DatabaseConfig.TABLE_FILE_COLLECTION_REFS)
    predicates.equalTo('file_id', fileId)
    predicates.and()
    predicates.equalTo('collection_id', collectionId)
    
    const resultSet = await store.query(predicates)
    const exists = resultSet.goToFirstRow()
    resultSet.close()
    
    return exists
  }
  
  /**
   * 获取收纳箱中的文件数量
   */
  async countByCollectionId(collectionId: number): Promise<number> {
    const store = await this.getStore()
    const sql = `SELECT COUNT(*) as count FROM ${DatabaseConfig.TABLE_FILE_COLLECTION_REFS} WHERE collection_id = ?`
    const resultSet = await store.querySql(sql, [collectionId.toString()])
    
    if (resultSet.goToFirstRow()) {
      const count = resultSet.getLong(0)
      resultSet.close()
      return count
    }
    
    resultSet.close()
    return 0
  }
  
  /**
   * 辅助方法：将 ResultSet 当前行转换为对象
   */
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
        case relationalStore.ColumnType.TYPE_FLOAT:
          row[columnName] = resultSet.getDouble(i)
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

- [ ] **Step 3: 编写 FileCollectionRefRepository 测试**

```typescript
// entry/src/test/ets/data/FileCollectionRefRepositoryTest.ets

import { describe, it, expect, beforeAll, afterEach } from '@ohos/hypium'
import { FileCollectionRefRepository } from '../../../main/ets/data/repository/FileCollectionRefRepository'
import { FileRepository } from '../../../main/ets/data/repository/FileRepository'
import { CollectionRepository } from '../../../main/ets/data/repository/CollectionRepository'
import { FileInfo } from '../../../main/ets/data/model/FileInfo'
import { Collection } from '../../../main/ets/data/model/Collection'
import { DatabaseManager } from '../../../main/ets/data/database/DatabaseManager'

export default function fileCollectionRefRepositoryTest() {
  describe('FileCollectionRefRepository', () => {
    let refRepository: FileCollectionRefRepository
    let fileRepository: FileRepository
    let collectionRepository: CollectionRepository
    let testFileId: number
    let testCollectionId: number
    
    beforeAll(async () => {
      await DatabaseManager.getInstance().init(getContext())
      refRepository = new FileCollectionRefRepository()
      fileRepository = new FileRepository()
      collectionRepository = new CollectionRepository()
      
      // 创建测试文件
      const fileInfo = new FileInfo({
        uri: 'file://test.pdf',
        name: 'test.pdf',
        type: 'application/pdf',
        size: 1024,
        path: '/data/test.pdf',
        createdTime: Date.now(),
        modifiedTime: Date.now()
      })
      testFileId = await fileRepository.insert(fileInfo)
      
      // 创建测试收纳箱
      const collection = new Collection({
        name: 'Test Collection',
        rules: []
      })
      testCollectionId = await collectionRepository.insert(collection)
    })
    
    afterEach(async () => {
      const store = await DatabaseManager.getInstance().getStore()
      await store.executeSql('DELETE FROM file_collection_refs')
    })
    
    it('should add file-collection ref', async () => {
      const refId = await refRepository.addRef(testFileId, testCollectionId, 0.95, 'llm')
      expect(refId).assertLarger(0)
    })
    
    it('should find refs by file id', async () => {
      await refRepository.addRef(testFileId, testCollectionId, 0.95, 'llm')
      
      const refs = await refRepository.findByFileId(testFileId)
      expect(refs.length).assertEqual(1)
      expect(refs[0].collectionId).assertEqual(testCollectionId)
      expect(refs[0].confidence).assertEqual(0.95)
    })
    
    it('should find refs by collection id', async () => {
      await refRepository.addRef(testFileId, testCollectionId, 0.95, 'llm')
      
      const refs = await refRepository.findByCollectionId(testCollectionId)
      expect(refs.length).assertEqual(1)
      expect(refs[0].fileId).assertEqual(testFileId)
    })
    
    it('should remove ref', async () => {
      await refRepository.addRef(testFileId, testCollectionId, 0.95, 'llm')
      await refRepository.removeRef(testFileId, testCollectionId)
      
      const refs = await refRepository.findByFileId(testFileId)
      expect(refs.length).assertEqual(0)
    })
    
    it('should check if ref exists', async () => {
      const existsBefore = await refRepository.exists(testFileId, testCollectionId)
      expect(existsBefore).assertFalse()
      
      await refRepository.addRef(testFileId, testCollectionId, 0.95, 'llm')
      
      const existsAfter = await refRepository.exists(testFileId, testCollectionId)
      expect(existsAfter).assertTrue()
    })
    
    it('should count files in collection', async () => {
      await refRepository.addRef(testFileId, testCollectionId, 0.95, 'llm')
      
      const count = await refRepository.countByCollectionId(testCollectionId)
      expect(count).assertEqual(1)
    })
    
    it('should not add duplicate ref', async () => {
      await refRepository.addRef(testFileId, testCollectionId, 0.95, 'llm')
      
      // 尝试添加重复关联应该失败（UNIQUE 约束）
      try {
        await refRepository.addRef(testFileId, testCollectionId, 0.90, 'manual')
        expect(false).assertTrue() // 不应该到达这里
      } catch (err) {
        expect(true).assertTrue() // 预期抛出异常
      }
    })
  })
}
```

- [ ] **Step 4: 运行测试**

运行: `ohpm test`

预期: 所有 FileCollectionRefRepository 测试通过

- [ ] **Step 5: 提交代码**

```bash
git add entry/src/main/ets/data/model/FileCollectionRef.ets
git add entry/src/main/ets/data/repository/FileCollectionRefRepository.ets
git add entry/src/test/ets/data/FileCollectionRefRepositoryTest.ets
git commit -m "feat: add FileCollectionRef relationship management

- Create FileCollectionRef model for file-collection associations
- Support both 'link' and 'physical' reference types
- Track confidence and creation source (llm/manual)
- Implement bidirectional queries (by file or collection)
- Enforce unique constraint on file-collection pairs
- Full test coverage with integration tests

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

## Task 5: 向量存储层管理 (VectorStorageTierRepository)

**Files:**
- Create: `entry/src/main/ets/data/model/VectorStorageTier.ets`
- Create: `entry/src/main/ets/data/repository/VectorStorageTierRepository.ets`
- Test: `entry/src/test/ets/data/VectorStorageTierRepositoryTest.ets`

**Interfaces:**
- Consumes: `DatabaseManager.getStore(): Promise<relationalStore.RdbStore>`
- Produces:
  - `VectorStorageTierRepository.setTier(fileId: number, tier: 'hot' | 'cold'): Promise<void>` - 设置分层
  - `VectorStorageTierRepository.getTier(fileId: number): Promise<'hot' | 'cold' | null>` - 获取分层
  - `VectorStorageTierRepository.findByTier(tier: 'hot' | 'cold'): Promise<VectorStorageTier[]>` - 查询指定层级的文件
  - `VectorStorageTierRepository.updateAccessTime(fileId: number): Promise<void>` - 更新访问时间
  - `VectorStorageTierRepository.findColdCandidates(olderThanDays: number): Promise<number[]>` - 查找可降级为冷数据的文件

---

- [ ] **Step 1: 创建 VectorStorageTier 模型**

```typescript
// entry/src/main/ets/data/model/VectorStorageTier.ets

export type TierType = 'hot' | 'cold'

export class VectorStorageTier {
  fileId: number
  tier: TierType
  lastAccessed: number
  accessCount: number = 1
  
  constructor(init?: Partial<VectorStorageTier>) {
    Object.assign(this, init)
  }
  
  /**
   * 从数据库行转换
   */
  static fromRow(row: any): VectorStorageTier {
    return new VectorStorageTier({
      fileId: row.file_id,
      tier: row.tier as TierType,
      lastAccessed: row.last_accessed,
      accessCount: row.access_count
    })
  }
  
  /**
   * 转换为数据库行对象
   */
  toValuesBucket(): Record<string, any> {
    return {
      file_id: this.fileId,
      tier: this.tier,
      last_accessed: this.lastAccessed,
      access_count: this.accessCount
    }
  }
}
```

- [ ] **Step 2: 创建 VectorStorageTierRepository**

```typescript
// entry/src/main/ets/data/repository/VectorStorageTierRepository.ets

import relationalStore from '@ohos.data.relationalStore'
import { DatabaseManager } from '../database/DatabaseManager'
import { DatabaseConfig } from '../database/DatabaseConfig'
import { VectorStorageTier, TierType } from '../model/VectorStorageTier'

export class VectorStorageTierRepository {
  private async getStore(): Promise<relationalStore.RdbStore> {
    return await DatabaseManager.getInstance().getStore()
  }
  
  /**
   * 设置文件的存储层级
   */
  async setTier(fileId: number, tier: TierType): Promise<void> {
    const existing = await this.getTier(fileId)
    
    if (existing) {
      // 更新现有记录
      const store = await this.getStore()
      const predicates = new relationalStore.RdbPredicates(DatabaseConfig.TABLE_VECTOR_STORAGE_TIERS)
      predicates.equalTo('file_id', fileId)
      
      const values = {
        tier: tier,
        last_accessed: Date.now()
      }
      
      await store.update(values, predicates)
    } else {
      // 插入新记录
      const tierInfo = new VectorStorageTier({
        fileId,
        tier,
        lastAccessed: Date.now(),
        accessCount: 1
      })
      
      const store = await this.getStore()
      const values = tierInfo.toValuesBucket()
      await store.insert(DatabaseConfig.TABLE_VECTOR_STORAGE_TIERS, values)
    }
  }
  
  /**
   * 获取文件的存储层级
   */
  async getTier(fileId: number): Promise<TierType | null> {
    const store = await this.getStore()
    const predicates = new relationalStore.RdbPredicates(DatabaseConfig.TABLE_VECTOR_STORAGE_TIERS)
    predicates.equalTo('file_id', fileId)
    
    const resultSet = await store.query(predicates)
    
    if (resultSet.goToFirstRow()) {
      const rowData = this.resultSetToObject(resultSet)
      resultSet.close()
      const tierInfo = VectorStorageTier.fromRow(rowData)
      return tierInfo.tier
    }
    
    resultSet.close()
    return null
  }
  
  /**
   * 查询指定层级的所有文件
   */
  async findByTier(tier: TierType): Promise<VectorStorageTier[]> {
    const store = await this.getStore()
    const predicates = new relationalStore.RdbPredicates(DatabaseConfig.TABLE_VECTOR_STORAGE_TIERS)
    predicates.equalTo('tier', tier)
    
    const resultSet = await store.query(predicates)
    const tiers: VectorStorageTier[] = []
    
    while (resultSet.goToNextRow()) {
      const rowData = this.resultSetToObject(resultSet)
      tiers.push(VectorStorageTier.fromRow(rowData))
    }
    
    resultSet.close()
    return tiers
  }
  
  /**
   * 更新文件的访问时间和访问次数
   */
  async updateAccessTime(fileId: number): Promise<void> {
    const store = await this.getStore()
    const predicates = new relationalStore.RdbPredicates(DatabaseConfig.TABLE_VECTOR_STORAGE_TIERS)
    predicates.equalTo('file_id', fileId)
    
    // 使用 SQL 更新以原子性地增加计数
    const sql = `UPDATE ${DatabaseConfig.TABLE_VECTOR_STORAGE_TIERS} 
                 SET last_accessed = ?, access_count = access_count + 1 
                 WHERE file_id = ?`
    await store.executeSql(sql, [Date.now().toString(), fileId.toString()])
  }
  
  /**
   * 查找可以降级为冷数据的文件
   * 规则：超过 N 天未访问，或访问次数 < 3 且超过 7 天
   */
  async findColdCandidates(olderThanDays: number = 30): Promise<number[]> {
    const store = await this.getStore()
    const threshold = Date.now() - (olderThanDays * 24 * 60 * 60 * 1000)
    const sevenDaysAgo = Date.now() - (7 * 24 * 60 * 60 * 1000)
    
    const sql = `
      SELECT file_id FROM ${DatabaseConfig.TABLE_VECTOR_STORAGE_TIERS}
      WHERE tier = 'hot' AND (
        last_accessed < ? OR
        (access_count < 3 AND last_accessed < ?)
      )
    `
    
    const resultSet = await store.querySql(sql, [threshold.toString(), sevenDaysAgo.toString()])
    const fileIds: number[] = []
    
    while (resultSet.goToNextRow()) {
      fileIds.push(resultSet.getLong(0))
    }
    
    resultSet.close()
    return fileIds
  }
  
  /**
   * 批量降级为冷数据
   */
  async demoteToCold(fileIds: number[]): Promise<void> {
    if (fileIds.length === 0) return
    
    const store = await this.getStore()
    const placeholders = fileIds.map(() => '?').join(',')
    const sql = `UPDATE ${DatabaseConfig.TABLE_VECTOR_STORAGE_TIERS} 
                 SET tier = 'cold' 
                 WHERE file_id IN (${placeholders})`
    
    await store.executeSql(sql, fileIds.map(id => id.toString()))
  }
  
  /**
   * 批量提升为热数据
   */
  async promoteToHot(fileIds: number[]): Promise<void> {
    if (fileIds.length === 0) return
    
    const store = await this.getStore()
    const placeholders = fileIds.map(() => '?').join(',')
    const sql = `UPDATE ${DatabaseConfig.TABLE_VECTOR_STORAGE_TIERS} 
                 SET tier = 'hot', last_accessed = ? 
                 WHERE file_id IN (${placeholders})`
    
    const args = [Date.now().toString(), ...fileIds.map(id => id.toString())]
    await store.executeSql(sql, args)
  }
  
  /**
   * 获取存储统计信息
   */
  async getStats(): Promise<{ hotCount: number, coldCount: number }> {
    const store = await this.getStore()
    const sql = `
      SELECT 
        SUM(CASE WHEN tier = 'hot' THEN 1 ELSE 0 END) as hot_count,
        SUM(CASE WHEN tier = 'cold' THEN 1 ELSE 0 END) as cold_count
      FROM ${DatabaseConfig.TABLE_VECTOR_STORAGE_TIERS}
    `
    
    const resultSet = await store.querySql(sql)
    
    if (resultSet.goToFirstRow()) {
      const hotCount = resultSet.getLong(0)
      const coldCount = resultSet.getLong(1)
      resultSet.close()
      return { hotCount, coldCount }
    }
    
    resultSet.close()
    return { hotCount: 0, coldCount: 0 }
  }
  
  /**
   * 辅助方法：将 ResultSet 当前行转换为对象
   */
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
        case relationalStore.ColumnType.TYPE_FLOAT:
          row[columnName] = resultSet.getDouble(i)
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

- [ ] **Step 3: 编写 VectorStorageTierRepository 测试**

```typescript
// entry/src/test/ets/data/VectorStorageTierRepositoryTest.ets

import { describe, it, expect, beforeAll, afterEach } from '@ohos/hypium'
import { VectorStorageTierRepository } from '../../../main/ets/data/repository/VectorStorageTierRepository'
import { DatabaseManager } from '../../../main/ets/data/database/DatabaseManager'
import { FileRepository } from '../../../main/ets/data/repository/FileRepository'
import { FileInfo } from '../../../main/ets/data/model/FileInfo'

export default function vectorStorageTierRepositoryTest() {
  describe('VectorStorageTierRepository', () => {
    let repository: VectorStorageTierRepository
    let fileRepository: FileRepository
    let testFileId: number
    
    beforeAll(async () => {
      await DatabaseManager.getInstance().init(getContext())
      repository = new VectorStorageTierRepository()
      fileRepository = new FileRepository()
      
      // 创建测试文件
      const fileInfo = new FileInfo({
        uri: 'file://test.pdf',
        name: 'test.pdf',
        type: 'application/pdf',
        size: 1024,
        path: '/data/test.pdf',
        createdTime: Date.now(),
        modifiedTime: Date.now()
      })
      testFileId = await fileRepository.insert(fileInfo)
    })
    
    afterEach(async () => {
      const store = await DatabaseManager.getInstance().getStore()
      await store.executeSql('DELETE FROM vector_storage_tiers')
    })
    
    it('should set file tier', async () => {
      await repository.setTier(testFileId, 'hot')
      const tier = await repository.getTier(testFileId)
      expect(tier).assertEqual('hot')
    })
    
    it('should update existing tier', async () => {
      await repository.setTier(testFileId, 'hot')
      await repository.setTier(testFileId, 'cold')
      
      const tier = await repository.getTier(testFileId)
      expect(tier).assertEqual('cold')
    })
    
    it('should find files by tier', async () => {
      await repository.setTier(testFileId, 'hot')
      
      const hotFiles = await repository.findByTier('hot')
      expect(hotFiles.length).assertEqual(1)
      expect(hotFiles[0].fileId).assertEqual(testFileId)
      
      const coldFiles = await repository.findByTier('cold')
      expect(coldFiles.length).assertEqual(0)
    })
    
    it('should update access time and count', async () => {
      await repository.setTier(testFileId, 'hot')
      
      const before = await repository.findByTier('hot')
      const initialCount = before[0].accessCount
      
      await repository.updateAccessTime(testFileId)
      
      const after = await repository.findByTier('hot')
      expect(after[0].accessCount).assertEqual(initialCount + 1)
      expect(after[0].lastAccessed).assertLarger(before[0].lastAccessed)
    })
    
    it('should find cold candidates', async () => {
      // 设置一个很旧的访问时间
      await repository.setTier(testFileId, 'hot')
      
      const store = await DatabaseManager.getInstance().getStore()
      const oldTime = Date.now() - (40 * 24 * 60 * 60 * 1000) // 40 天前
      await store.executeSql(
        'UPDATE vector_storage_tiers SET last_accessed = ? WHERE file_id = ?',
        [oldTime.toString(), testFileId.toString()]
      )
      
      const candidates = await repository.findColdCandidates(30)
      expect(candidates.length).assertEqual(1)
      expect(candidates[0]).assertEqual(testFileId)
    })
    
    it('should demote to cold in batch', async () => {
      await repository.setTier(testFileId, 'hot')
      await repository.demoteToCold([testFileId])
      
      const tier = await repository.getTier(testFileId)
      expect(tier).assertEqual('cold')
    })
    
    it('should promote to hot in batch', async () => {
      await repository.setTier(testFileId, 'cold')
      await repository.promoteToHot([testFileId])
      
      const tier = await repository.getTier(testFileId)
      expect(tier).assertEqual('hot')
    })
    
    it('should get storage stats', async () => {
      const file2 = new FileInfo({
        uri: 'file://test2.pdf',
        name: 'test2.pdf',
        type: 'application/pdf',
        size: 2048,
        path: '/data/test2.pdf',
        createdTime: Date.now(),
        modifiedTime: Date.now()
      })
      const file2Id = await fileRepository.insert(file2)
      
      await repository.setTier(testFileId, 'hot')
      await repository.setTier(file2Id, 'cold')
      
      const stats = await repository.getStats()
      expect(stats.hotCount).assertEqual(1)
      expect(stats.coldCount).assertEqual(1)
    })
  })
}
```

- [ ] **Step 4: 运行测试**

运行: `ohpm test`

预期: 所有 VectorStorageTierRepository 测试通过

- [ ] **Step 5: 提交代码**

```bash
git add entry/src/main/ets/data/model/VectorStorageTier.ets
git add entry/src/main/ets/data/repository/VectorStorageTierRepository.ets
git add entry/src/test/ets/data/VectorStorageTierRepositoryTest.ets
git commit -m "feat: add vector storage tier management

- Create VectorStorageTier model for hot/cold data tracking
- Track access time and count for tier promotion logic
- Implement cold candidate detection (30 days or low access)
- Support batch tier promotion/demotion
- Provide storage statistics (hot/cold counts)
- Full test coverage including edge cases

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

## Task 6: RAG 分析日志管理 (RagAnalysisLogRepository)

**Files:**
- Create: `entry/src/main/ets/data/model/RagAnalysisLog.ets`
- Create: `entry/src/main/ets/data/repository/RagAnalysisLogRepository.ets`
- Test: `entry/src/test/ets/data/RagAnalysisLogRepositoryTest.ets`

**Interfaces:**
- Consumes: `DatabaseManager.getStore(): Promise<relationalStore.RdbStore>`
- Produces:
  - `RagAnalysisLogRepository.createLog(batchId: string, fileCount: number): Promise<number>` - 创建分析日志
  - `RagAnalysisLogRepository.updateStatus(logId: number, status: 'running' | 'completed' | 'failed', endTime?: number, tokensUsed?: number, errorMessage?: string): Promise<void>` - 更新状态
  - `RagAnalysisLogRepository.findRecent(limit?: number): Promise<RagAnalysisLog[]>` - 查询最近的日志
  - `RagAnalysisLogRepository.getTotalTokensUsed(sinceTime?: number): Promise<number>` - 统计 Token 消耗

---

- [ ] **Step 1: 创建 RagAnalysisLog 模型**

```typescript
// entry/src/main/ets/data/model/RagAnalysisLog.ets

export type LogStatus = 'running' | 'completed' | 'failed'

export class RagAnalysisLog {
  id?: number
  batchId: string
  fileCount: number
  startTime: number = Date.now()
  endTime?: number
  llmTokensUsed?: number
  status: LogStatus = 'running'
  errorMessage?: string
  
  constructor(init?: Partial<RagAnalysisLog>) {
    Object.assign(this, init)
  }
  
  /**
   * 从数据库行转换
   */
  static fromRow(row: any): RagAnalysisLog {
    return new RagAnalysisLog({
      id: row.id,
      batchId: row.batch_id,
      fileCount: row.file_count,
      startTime: row.start_time,
      endTime: row.end_time,
      llmTokensUsed: row.llm_tokens_used,
      status: row.status as LogStatus,
      errorMessage: row.error_message
    })
  }
  
  /**
   * 转换为数据库行对象
   */
  toValuesBucket(): Record<string, any> {
    const values: Record<string, any> = {
      batch_id: this.batchId,
      file_count: this.fileCount,
      start_time: this.startTime,
      status: this.status
    }
    
    if (this.endTime) values.end_time = this.endTime
    if (this.llmTokensUsed) values.llm_tokens_used = this.llmTokensUsed
    if (this.errorMessage) values.error_message = this.errorMessage
    
    return values
  }
  
  /**
   * 计算执行时长（毫秒）
   */
  getDuration(): number | null {
    if (!this.endTime) return null
    return this.endTime - this.startTime
  }
  
  /**
   * 是否完成
   */
  isCompleted(): boolean {
    return this.status === 'completed' || this.status === 'failed'
  }
}
```

- [ ] **Step 2: 创建 RagAnalysisLogRepository**

```typescript
// entry/src/main/ets/data/repository/RagAnalysisLogRepository.ets

import relationalStore from '@ohos.data.relationalStore'
import { DatabaseManager } from '../database/DatabaseManager'
import { DatabaseConfig } from '../database/DatabaseConfig'
import { RagAnalysisLog, LogStatus } from '../model/RagAnalysisLog'

export class RagAnalysisLogRepository {
  private async getStore(): Promise<relationalStore.RdbStore> {
    return await DatabaseManager.getInstance().getStore()
  }
  
  /**
   * 创建分析日志
   */
  async createLog(batchId: string, fileCount: number): Promise<number> {
    const log = new RagAnalysisLog({
      batchId,
      fileCount,
      status: 'running'
    })
    
    const store = await this.getStore()
    const values = log.toValuesBucket()
    return await store.insert(DatabaseConfig.TABLE_RAG_ANALYSIS_LOGS, values)
  }
  
  /**
   * 更新日志状态
   */
  async updateStatus(
    logId: number, 
    status: LogStatus, 
    endTime?: number, 
    tokensUsed?: number, 
    errorMessage?: string
  ): Promise<void> {
    const store = await this.getStore()
    const predicates = new relationalStore.RdbPredicates(DatabaseConfig.TABLE_RAG_ANALYSIS_LOGS)
    predicates.equalTo('id', logId)
    
    const values: Record<string, any> = {
      status: status
    }
    
    if (endTime) values.end_time = endTime
    if (tokensUsed) values.llm_tokens_used = tokensUsed
    if (errorMessage) values.error_message = errorMessage
    
    await store.update(values, predicates)
  }
  
  /**
   * 根据 ID 查询日志
   */
  async findById(id: number): Promise<RagAnalysisLog | null> {
    const store = await this.getStore()
    const predicates = new relationalStore.RdbPredicates(DatabaseConfig.TABLE_RAG_ANALYSIS_LOGS)
    predicates.equalTo('id', id)
    
    const resultSet = await store.query(predicates)
    
    if (resultSet.goToFirstRow()) {
      const rowData = this.resultSetToObject(resultSet)
      resultSet.close()
      return RagAnalysisLog.fromRow(rowData)
    }
    
    resultSet.close()
    return null
  }
  
  /**
   * 查询最近的日志
   */
  async findRecent(limit: number = 20): Promise<RagAnalysisLog[]> {
    const store = await this.getStore()
    const predicates = new relationalStore.RdbPredicates(DatabaseConfig.TABLE_RAG_ANALYSIS_LOGS)
    predicates.orderByDesc('start_time')
    predicates.limit(limit)
    
    const resultSet = await store.query(predicates)
    const logs: RagAnalysisLog[] = []
    
    while (resultSet.goToNextRow()) {
      const rowData = this.resultSetToObject(resultSet)
      logs.push(RagAnalysisLog.fromRow(rowData))
    }
    
    resultSet.close()
    return logs
  }
  
  /**
   * 统计总 Token 消耗
   */
  async getTotalTokensUsed(sinceTime?: number): Promise<number> {
    const store = await this.getStore()
    let sql = `SELECT SUM(llm_tokens_used) as total FROM ${DatabaseConfig.TABLE_RAG_ANALYSIS_LOGS} WHERE llm_tokens_used IS NOT NULL`
    const args: string[] = []
    
    if (sinceTime) {
      sql += ' AND start_time >= ?'
      args.push(sinceTime.toString())
    }
    
    const resultSet = await store.querySql(sql, args)
    
    if (resultSet.goToFirstRow()) {
      const total = resultSet.getLong(0)
      resultSet.close()
      return total
    }
    
    resultSet.close()
    return 0
  }
  
  /**
   * 获取统计信息
   */
  async getStatistics(sinceTime?: number): Promise<{
    totalBatches: number,
    totalFiles: number,
    totalTokens: number,
    successRate: number,
    avgDuration: number
  }> {
    const store = await this.getStore()
    let sql = `
      SELECT 
        COUNT(*) as total_batches,
        SUM(file_count) as total_files,
        SUM(llm_tokens_used) as total_tokens,
        SUM(CASE WHEN status = 'completed' THEN 1 ELSE 0 END) as completed,
        AVG(CASE WHEN end_time IS NOT NULL THEN end_time - start_time ELSE NULL END) as avg_duration
      FROM ${DatabaseConfig.TABLE_RAG_ANALYSIS_LOGS}
    `
    const args: string[] = []
    
    if (sinceTime) {
      sql += ' WHERE start_time >= ?'
      args.push(sinceTime.toString())
    }
    
    const resultSet = await store.querySql(sql, args)
    
    if (resultSet.goToFirstRow()) {
      const totalBatches = resultSet.getLong(0)
      const totalFiles = resultSet.getLong(1)
      const totalTokens = resultSet.getLong(2)
      const completed = resultSet.getLong(3)
      const avgDuration = resultSet.getDouble(4)
      
      resultSet.close()
      
      const successRate = totalBatches > 0 ? (completed / totalBatches) * 100 : 0
      
      return {
        totalBatches,
        totalFiles,
        totalTokens,
        successRate,
        avgDuration
      }
    }
    
    resultSet.close()
    return {
      totalBatches: 0,
      totalFiles: 0,
      totalTokens: 0,
      successRate: 0,
      avgDuration: 0
    }
  }
  
  /**
   * 删除旧日志
   */
  async deleteOlderThan(days: number): Promise<number> {
    const store = await this.getStore()
    const threshold = Date.now() - (days * 24 * 60 * 60 * 1000)
    
    const predicates = new relationalStore.RdbPredicates(DatabaseConfig.TABLE_RAG_ANALYSIS_LOGS)
    predicates.lessThan('start_time', threshold)
    
    return await store.delete(predicates)
  }
  
  /**
   * 辅助方法：将 ResultSet 当前行转换为对象
   */
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
        case relationalStore.ColumnType.TYPE_FLOAT:
          row[columnName] = resultSet.getDouble(i)
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

- [ ] **Step 3: 编写 RagAnalysisLogRepository 测试**

```typescript
// entry/src/test/ets/data/RagAnalysisLogRepositoryTest.ets

import { describe, it, expect, beforeAll, afterEach } from '@ohos/hypium'
import { RagAnalysisLogRepository } from '../../../main/ets/data/repository/RagAnalysisLogRepository'
import { DatabaseManager } from '../../../main/ets/data/database/DatabaseManager'

export default function ragAnalysisLogRepositoryTest() {
  describe('RagAnalysisLogRepository', () => {
    let repository: RagAnalysisLogRepository
    
    beforeAll(async () => {
      await DatabaseManager.getInstance().init(getContext())
      repository = new RagAnalysisLogRepository()
    })
    
    afterEach(async () => {
      const store = await DatabaseManager.getInstance().getStore()
      await store.executeSql('DELETE FROM rag_analysis_logs')
    })
    
    it('should create log with running status', async () => {
      const logId = await repository.createLog('batch-001', 10)
      expect(logId).assertLarger(0)
      
      const log = await repository.findById(logId)
      expect(log).assertNotNull()
      expect(log!.status).assertEqual('running')
      expect(log!.fileCount).assertEqual(10)
    })
    
    it('should update log status to completed', async () => {
      const logId = await repository.createLog('batch-002', 5)
      const endTime = Date.now()
      
      await repository.updateStatus(logId, 'completed', endTime, 1500)
      
      const log = await repository.findById(logId)
      expect(log!.status).assertEqual('completed')
      expect(log!.endTime).assertEqual(endTime)
      expect(log!.llmTokensUsed).assertEqual(1500)
    })
    
    it('should update log status to failed with error', async () => {
      const logId = await repository.createLog('batch-003', 8)
      const endTime = Date.now()
      
      await repository.updateStatus(logId, 'failed', endTime, undefined, 'Network error')
      
      const log = await repository.findById(logId)
      expect(log!.status).assertEqual('failed')
      expect(log!.errorMessage).assertEqual('Network error')
    })
    
    it('should find recent logs', async () => {
      await repository.createLog('batch-001', 5)
      await repository.createLog('batch-002', 10)
      await repository.createLog('batch-003', 15)
      
      const recent = await repository.findRecent(2)
      expect(recent.length).assertEqual(2)
      // 最新的在前
      expect(recent[0].batchId).assertEqual('batch-003')
      expect(recent[1].batchId).assertEqual('batch-002')
    })
    
    it('should calculate total tokens used', async () => {
      const log1Id = await repository.createLog('batch-001', 5)
      const log2Id = await repository.createLog('batch-002', 10)
      
      await repository.updateStatus(log1Id, 'completed', Date.now(), 1000)
      await repository.updateStatus(log2Id, 'completed', Date.now(), 1500)
      
      const total = await repository.getTotalTokensUsed()
      expect(total).assertEqual(2500)
    })
    
    it('should calculate tokens used since time', async () => {
      const now = Date.now()
      const log1Id = await repository.createLog('batch-001', 5)
      
      // 模拟旧日志
      const store = await DatabaseManager.getInstance().getStore()
      await store.executeSql(
        'UPDATE rag_analysis_logs SET start_time = ?, llm_tokens_used = 500 WHERE id = ?',
        [(now - 10000).toString(), log1Id.toString()]
      )
      
      // 新日志
      const log2Id = await repository.createLog('batch-002', 10)
      await repository.updateStatus(log2Id, 'completed', Date.now(), 1500)
      
      const total = await repository.getTotalTokensUsed(now - 5000)
      expect(total).assertEqual(1500) // 只统计新日志
    })
    
    it('should get statistics', async () => {
      const log1Id = await repository.createLog('batch-001', 10)
      const log2Id = await repository.createLog('batch-002', 20)
      const log3Id = await repository.createLog('batch-003', 15)
      
      await repository.updateStatus(log1Id, 'completed', Date.now(), 1000)
      await repository.updateStatus(log2Id, 'completed', Date.now(), 2000)
      await repository.updateStatus(log3Id, 'failed', Date.now(), undefined, 'Error')
      
      const stats = await repository.getStatistics()
      expect(stats.totalBatches).assertEqual(3)
      expect(stats.totalFiles).assertEqual(45)
      expect(stats.totalTokens).assertEqual(3000)
      expect(stats.successRate).assertClose(66.67, 0.1) // 2/3 * 100
    })
    
    it('should delete old logs', async () => {
      const now = Date.now()
      const log1Id = await repository.createLog('batch-old', 5)
      
      // 设置为 40 天前
      const store = await DatabaseManager.getInstance().getStore()
      await store.executeSql(
        'UPDATE rag_analysis_logs SET start_time = ? WHERE id = ?',
        [(now - 40 * 24 * 60 * 60 * 1000).toString(), log1Id.toString()]
      )
      
      await repository.createLog('batch-new', 10)
      
      const deletedCount = await repository.deleteOlderThan(30)
      expect(deletedCount).assertEqual(1)
      
      const remaining = await repository.findRecent()
      expect(remaining.length).assertEqual(1)
      expect(remaining[0].batchId).assertEqual('batch-new')
    })
  })
}
```

- [ ] **Step 4: 运行测试**

运行: `ohpm test`

预期: 所有 RagAnalysisLogRepository 测试通过

- [ ] **Step 5: 提交代码**

```bash
git add entry/src/main/ets/data/model/RagAnalysisLog.ets
git add entry/src/main/ets/data/repository/RagAnalysisLogRepository.ets
git add entry/src/test/ets/data/RagAnalysisLogRepositoryTest.ets
git commit -m "feat: add RAG analysis log tracking

- Create RagAnalysisLog model with status tracking
- Track batch execution time, file count, token usage
- Support error logging for failed analyses
- Calculate statistics (success rate, avg duration, total tokens)
- Automatic old log cleanup (configurable retention period)
- Full test coverage including time-based queries

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

## 自我审查

**1. Spec 覆盖检查:**
- ✅ 数据库 Schema - Task 1 实现
- ✅ 文件元数据存储 - Task 2 实现
- ✅ 收纳箱配置存储 - Task 3 实现
- ✅ 文件-收纳箱关联 - Task 4 实现
- ✅ 分层存储管理 - Task 5 实现
- ✅ RAG 分析日志 - Task 6 实现
- ⚠️ 向量表（file_embeddings, keyword_embeddings）未实现 - **预留给下一个子系统（向量检索系统）**

**2. 占位符扫描:**
- 无 TBD/TODO
- 所有代码完整
- 所有测试包含实际断言

**3. 类型一致性:**
- FileInfo 模型在所有地方使用一致
- Collection 和 CollectionRule 类型匹配
- FileCollectionRef 的 RefType 和 CreatedBy 类型定义明确
- VectorStorageTier 的 TierType 一致
- RagAnalysisLog 的 LogStatus 一致

**4. 遗留问题:**
- 向量表的创建延迟到向量检索系统实施时处理（因为需要特殊的向量扩展支持）
- 当前实施的是基础数据层，为后续子系统提供了完整的数据访问接口

---

## 总结

**已完成:**
- 6 个 Repository（数据访问层）
- 7 个数据模型
- 完整的单元测试覆盖
- 数据库初始化与 Schema 管理
- 分层存储策略实现
- RAG 分析日志跟踪

**文件结构:**
```
entry/src/main/ets/
├── data/
│   ├── database/
│   │   ├── DatabaseManager.ets
│   │   ├── DatabaseSchema.ets
│   │   └── DatabaseConfig.ets
│   ├── model/
│   │   ├── FileInfo.ets
│   │   ├── Collection.ets
│   │   ├── CollectionRule.ets
│   │   ├── FileCollectionRef.ets
│   │   ├── VectorStorageTier.ets
│   │   └── RagAnalysisLog.ets
│   └── repository/
│       ├── FileRepository.ets
│       ├── CollectionRepository.ets
│       ├── FileCollectionRefRepository.ets
│       ├── VectorStorageTierRepository.ets
│       └── RagAnalysisLogRepository.ets
```

**下一步:**
实施**向量检索系统**子系统，包括：
- SQLite Vector Extension 集成
- ONNX Runtime 集成
- Embedding 模型加载
- 向量存储与检索服务

**估算工作量:** 约 1-2 周
