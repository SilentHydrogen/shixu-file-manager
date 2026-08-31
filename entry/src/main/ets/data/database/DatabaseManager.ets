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
      // v2 changes vector contract to BGE 512 dimensions; existing file rows stay intact.
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
