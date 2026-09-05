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
  async init(context: common.Context): Promise<void> {
    if (this.initPromise) {
      return this.initPromise
    }

    this.initPromise = this.doInit(context)
    return this.initPromise
  }

  private async doInit(context: common.Context): Promise<void> {
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
    await this.migrateSchema(this.store)
  }

  private async migrateSchema(store: relationalStore.RdbStore): Promise<void> {
    await store.executeSql("INSERT OR IGNORE INTO schema_meta (key, value) VALUES ('schema_version', '1')")
    const resultSet = await store.querySql("SELECT value FROM schema_meta WHERE key = 'schema_version'")
    let version: number = 1
    try {
      if (resultSet.goToFirstRow()) version = parseInt(resultSet.getString(0))
    } finally {
      resultSet.close()
    }
    if (version < DatabaseConfig.DB_VERSION) {
      if (version < 2) await store.executeSql('DELETE FROM file_embeddings')
      if (version < 3) {
        try { await store.executeSql("ALTER TABLE files ADD COLUMN category TEXT DEFAULT '待整理'") } catch (error) { /* column already exists */ }
      }
      if (version < 4) {
        await store.executeSql(`CREATE TABLE IF NOT EXISTS category_lexicons (
          category_name TEXT PRIMARY KEY,
          subtitle TEXT NOT NULL,
          source TEXT NOT NULL,
          seed_keywords TEXT NOT NULL,
          expanded_keywords TEXT NOT NULL,
          embedding_vector TEXT NOT NULL,
          fingerprint TEXT NOT NULL,
          updated_time INTEGER NOT NULL
        )`)
      }
      await store.executeSql(`UPDATE schema_meta SET value = '${DatabaseConfig.DB_VERSION}' WHERE key = 'schema_version'`)
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
