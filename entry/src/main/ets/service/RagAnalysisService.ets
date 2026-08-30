// entry/src/main/ets/service/RagAnalysisService.ets

import { FileRepository } from '../data/repository/FileRepository'
import { VectorStore } from '../data/vector/VectorStore'
import { VectorIndex } from '../data/vector/VectorIndex'
import { RagAnalysisLogRepository } from '../data/repository/RagAnalysisLogRepository'
import { EmbeddingModel } from '../ai/model/EmbeddingModel'
import { FileProcessingQueue } from './FileProcessingQueue'
import { FileInfo } from '../data/model/FileInfo'
import { LLMService } from '../llm/LLMService'
import { FileAnalysisResult, QAResult, RelevantFile } from '../llm/LLMTypes'
import fs from '@ohos.file.fs'

export interface SearchResult {
  file: FileInfo
  score: number
}

export class RagAnalysisService {
  private fileRepo: FileRepository
  private vectorStore: VectorStore
  private vectorIndex: VectorIndex
  private logRepo: RagAnalysisLogRepository
  private embeddingModel: EmbeddingModel
  private queue: FileProcessingQueue
  private llmService: LLMService

  constructor() {
    this.fileRepo = new FileRepository()
    this.vectorStore = new VectorStore()
    this.vectorIndex = new VectorIndex()
    this.logRepo = new RagAnalysisLogRepository()
    this.embeddingModel = new EmbeddingModel()
    this.queue = new FileProcessingQueue()
    this.llmService = LLMService.getInstance()
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
  async search(query: string, topK: number = 10): Promise<SearchResult[]> {
    // 生成查询向量
    const queryVector = await this.embeddingModel.encode(query)

    // 向量检索
    const results = await this.vectorIndex.search(queryVector, topK)

    // 填充文件信息
    const enrichedResults: SearchResult[] = []

    for (const result of results) {
      const file = await this.fileRepo.findById(result.fileId)
      if (file) {
        const searchResult: SearchResult = {
          file,
          score: result.score
        }
        enrichedResults.push(searchResult)
      }
    }

    return enrichedResults
  }

  /**
   * 智能问答
   */
  async askQuestion(question: string, topK: number = 5): Promise<QAResult> {
    if (!this.llmService.isConfigured()) {
      throw new Error('LLM service is not configured')
    }

    // 1. 语义搜索相关文件
    const searchResults = await this.search(question, topK)

    // 2. 读取文件内容
    const relevantFiles: RelevantFile[] = []
    const filesForLLM: Array<{ name: string, content: string }> = []

    for (const result of searchResults) {
      try {
        const content = await this.readFileContent(result.file.path)
        relevantFiles.push({
          fileId: result.file.id ?? 0,
          fileName: result.file.name,
          similarity: result.score,
          snippet: content.substring(0, 200)
        })
        filesForLLM.push({
          name: result.file.name,
          content: content
        })
      } catch (err) {
        console.error(`Failed to read file ${result.file.path}:`, JSON.stringify(err))
      }
    }

    // 3. 调用 LLM 生成答案
    const answer = await this.llmService.answerQuestion(question, filesForLLM)

    // 4. 计算置信度（基于相似度）
    const avgSimilarity = relevantFiles.length > 0
      ? relevantFiles.reduce((sum, f) => sum + f.similarity, 0) / relevantFiles.length
      : 0

    return {
      answer,
      relevantFiles,
      confidence: avgSimilarity
    }
  }

  /**
   * 分析单个文件（使用 LLM）
   */
  async analyzeFile(fileId: number): Promise<FileAnalysisResult> {
    if (!this.llmService.isConfigured()) {
      throw new Error('LLM service is not configured')
    }

    const file = await this.fileRepo.findById(fileId)
    if (!file) {
      throw new Error(`File ${fileId} not found`)
    }

    // 读取文件内容
    const content = await this.readFileContent(file.path)

    // 使用 LLM 分析
    const summary = await this.llmService.summarizeFile(file.name, file.type, content)
    const keywords = await this.llmService.extractKeywords(content)
    const category = await this.llmService.categorizeFile(file.name, content)

    return {
      summary,
      keywords,
      category
    }
  }

  /**
   * 批量分析文件
   */
  async batchAnalyzeFiles(fileIds: number[]): Promise<void> {
    for (const fileId of fileIds) {
      try {
        await this.processFile(fileId)
      } catch (err) {
        console.error(`Failed to analyze file ${fileId}:`, JSON.stringify(err))
      }
    }
  }

  /**
   * 生成文本摘要
   */
  private async generateSummary(file: FileInfo): Promise<string> {
    if (!this.llmService.isConfigured()) {
      return `Summary of ${file.name} (LLM not configured)`
    }

    try {
      const content = await this.readFileContent(file.path)
      return await this.llmService.summarizeFile(file.name, file.type, content)
    } catch (err) {
      console.error('Failed to generate summary:', JSON.stringify(err))
      return `Summary of ${file.name}`
    }
  }

  /**
   * 提取关键词
   */
  private async extractKeywords(file: FileInfo): Promise<string[]> {
    if (!this.llmService.isConfigured()) {
      return ['keyword1', 'keyword2']
    }

    try {
      const content = await this.readFileContent(file.path)
      return await this.llmService.extractKeywords(content)
    } catch (err) {
      console.error('Failed to extract keywords:', JSON.stringify(err))
      return []
    }
  }

  /**
   * 生成 embedding 向量
   */
  private async generateEmbedding(file: FileInfo): Promise<number[]> {
    // 优先使用 LLM 服务生成 embedding
    if (this.llmService.isConfigured()) {
      try {
        const content = await this.readFileContent(file.path)
        const text = `${file.name} ${content.substring(0, 1000)}`
        return await this.llmService.generateEmbedding(text)
      } catch (err) {
        console.error('LLM embedding failed, fallback to local model:', JSON.stringify(err))
      }
    }

    // 降级使用本地模型
    const text = `${file.name} ${file.contentSummary || ''}`
    return await this.embeddingModel.encode(text)
  }

  /**
   * 读取文件内容
   */
  private async readFileContent(path: string): Promise<string> {
    try {
      const file = fs.openSync(path, fs.OpenMode.READ_ONLY)
      const buffer = new ArrayBuffer(8192)
      const readLen = fs.readSync(file.fd, buffer)
      fs.closeSync(file)

      const uint8Array = new Uint8Array(buffer, 0, readLen)
      const decoder = new TextDecoder('utf-8')
      return decoder.decode(uint8Array)
    } catch (err) {
      console.error(`Failed to read file ${path}:`, JSON.stringify(err))
      return ''
    }
  }
}
