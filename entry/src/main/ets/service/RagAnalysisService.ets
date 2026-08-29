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
