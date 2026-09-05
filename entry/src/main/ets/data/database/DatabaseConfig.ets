export class DatabaseConfig {
  static readonly DB_NAME: string = 'shixu_rag.db'
  static readonly DB_VERSION: number = 3
  static readonly VECTOR_DIMENSION: number = 512

  static readonly TABLE_FILES: string = 'files'
  static readonly TABLE_COLLECTIONS: string = 'collections'
  static readonly TABLE_FILE_COLLECTION_REFS: string = 'file_collection_refs'
  static readonly TABLE_VECTOR_STORAGE_TIERS: string = 'vector_storage_tiers'
  static readonly TABLE_RAG_ANALYSIS_LOGS: string = 'rag_analysis_logs'

  // 虚拟表（向量扩展）
  static readonly TABLE_FILE_EMBEDDINGS: string = 'file_embeddings'
  static readonly TABLE_KEYWORD_EMBEDDINGS: string = 'keyword_embeddings'
}
