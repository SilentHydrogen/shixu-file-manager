import { FileEmbedding } from '../model/FileEmbedding'
import { VectorStore } from './VectorStore'

export interface SearchResult {
  fileId: number
  score: number
}

export interface IndexStats {
  totalVectors: number
  dimension: number
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
      if (emb.embedding.length > 0) this.index.set(emb.fileId, emb.embedding)
    }

    this.isBuilt = true
  }

  /**
   * 向索引中添加新向量
   */
  addToIndex(fileId: number, embedding: number[]): void {
    if (embedding.length > 0) this.index.set(fileId, embedding)
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
    const iterator = this.index.entries()
    let entry = iterator.next()
    while (!entry.done) {
      const fileId = entry.value[0]
      const embedding = entry.value[1]
      if (queryVector.length !== embedding.length) { entry = iterator.next(); continue }
      const score = this.cosineSimilarity(queryVector, embedding)
      const result: SearchResult = { fileId, score }
      results.push(result)
      entry = iterator.next()
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
    let normA = 0
    let normB = 0
    for (let i = 0; i < a.length; i++) {
      dotProduct += a[i] * b[i]
      normA += a[i] * a[i]
      normB += b[i] * b[i]
    }
    return dotProduct / ((Math.sqrt(normA) * Math.sqrt(normB)) || 1)
  }

  /**
   * 获取索引统计信息
   */
  getStats(): IndexStats {
    const firstVector = this.index.values().next().value as number[] | undefined
    const stats: IndexStats = {
      totalVectors: this.index.size,
      dimension: firstVector ? firstVector.length : 0
    }
    return stats
  }
}
