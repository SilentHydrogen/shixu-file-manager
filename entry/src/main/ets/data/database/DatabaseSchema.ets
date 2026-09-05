export class DatabaseSchema {
  /**
   * 获取所有建表 SQL 语句
   */
  static getCreateTableSQLs(): string[] {
    return [
      DatabaseSchema.createSchemaMetaTable(),
      DatabaseSchema.createFilesTable(),
      DatabaseSchema.createCollectionsTable(),
      DatabaseSchema.createFileCollectionRefsTable(),
      DatabaseSchema.createVectorStorageTiersTable(),
      DatabaseSchema.createRagAnalysisLogsTable(),
      DatabaseSchema.createFileEmbeddingsTable(),
      DatabaseSchema.createKeywordEmbeddingsTable(),
      DatabaseSchema.createCategoryLexiconsTable()
    ]
  }

  private static createSchemaMetaTable(): string {
    return `
      CREATE TABLE IF NOT EXISTS schema_meta (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    `
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
        extracted_keywords TEXT,
        category TEXT DEFAULT '待整理'
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

  private static createKeywordEmbeddingsTable(): string {
    return `
      CREATE TABLE IF NOT EXISTS keyword_embeddings (
        keyword TEXT PRIMARY KEY,
        category TEXT NOT NULL,
        synonyms TEXT NOT NULL,
        embedding_vector TEXT NOT NULL,
        updated_time INTEGER NOT NULL
      )
    `
  }

  private static createCategoryLexiconsTable(): string {
    return `
      CREATE TABLE IF NOT EXISTS category_lexicons (
        category_name TEXT PRIMARY KEY,
        subtitle TEXT NOT NULL,
        source TEXT NOT NULL,
        seed_keywords TEXT NOT NULL,
        expanded_keywords TEXT NOT NULL,
        embedding_vector TEXT NOT NULL,
        fingerprint TEXT NOT NULL,
        updated_time INTEGER NOT NULL
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
      'CREATE INDEX IF NOT EXISTS idx_vector_storage_tiers_tier ON vector_storage_tiers(tier)',
      'CREATE INDEX IF NOT EXISTS idx_keyword_embeddings_category ON keyword_embeddings(category)',
      'CREATE INDEX IF NOT EXISTS idx_category_lexicons_source ON category_lexicons(source)'
    ]
  }
}
