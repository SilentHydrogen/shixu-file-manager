import { FileRepository } from '../data/repository/FileRepository'
import { VectorStore } from '../data/vector/VectorStore'
import { VectorIndex } from '../data/vector/VectorIndex'
import { RagAnalysisLogRepository } from '../data/repository/RagAnalysisLogRepository'
import { EmbeddingModel } from '../ai/model/EmbeddingModel'
import { FileInfo } from '../data/model/FileInfo'
import { LLMService } from '../llm/LLMService'
import { FileAnalysisResult, QAResult, RelevantFile, RelevantContext } from '../llm/LLMTypes'
import { chunkText, limitLeadingText } from '../llm/RagTextUtils'
import fs from '@ohos.file.fs'

export interface SearchResult { file: FileInfo; score: number }

export class RagAnalysisService {
  private fileRepo: FileRepository = new FileRepository()
  private vectorStore: VectorStore = new VectorStore()
  private vectorIndex: VectorIndex = new VectorIndex()
  private logRepo: RagAnalysisLogRepository = new RagAnalysisLogRepository()
  private embeddingModel: EmbeddingModel = new EmbeddingModel()
  private llmService: LLMService = LLMService.getInstance()

  async initialize(): Promise<void> {
    try { await this.embeddingModel.loadModel() } catch (error) {
      console.warn('Local embedding unavailable; lexical search enabled')
    }
    try { await this.vectorIndex.build() } catch (error) {
      console.warn('Vector index unavailable; lexical search enabled')
    }
  }

  async processFile(fileId: number): Promise<void> {
    const file: FileInfo | null = await this.fileRepo.findById(fileId)
    if (file === null) throw new Error(`File ${fileId} not found`)
    const content: string = limitLeadingText(await this.readFileContent(file.path))
    let summary: string = content.length > 0 ? content.substring(0, 200) : file.name
    let keywords: string[] = file.name.split(/[ ._-]+/).filter((item: string) => item.length > 0).slice(0, 5)
    if (this.llmService.isConfigured()) {
      try {
        const analysis: FileAnalysisResult = await this.llmService.analyzeFile(
          file.name, file.type, content, ['工作', '项目', '生活', '灵感', '待整理'])
        summary = analysis.summary
        keywords = analysis.keywords
      } catch (error) {
        console.warn('LLM file analysis failed; retaining local extraction')
      }
    }
    if (this.embeddingModel.isAvailable()) {
      try {
        const embedding: number[] = await this.embeddingModel.encode(`${file.name}\n${content}`)
        await this.vectorStore.saveEmbedding(fileId, embedding)
        this.vectorIndex.addToIndex(fileId, embedding)
      } catch (error) {
        console.warn('Local embedding failed; file remains searchable by keywords')
      }
    }
    await this.fileRepo.updateContentSummary(fileId, summary, keywords)
    await this.fileRepo.markAsProcessed(fileId)
  }

  async processBatch(fileIds: number[]): Promise<void> {
    const ids: number[] = fileIds.slice(0, 20)
    const logId: number = await this.logRepo.createLog(`batch-${Date.now()}`, ids.length)
    for (const fileId of ids) {
      try { await this.processFile(fileId) } catch (error) {
        console.error(`Failed to process file ${fileId}`)
      }
    }
    await this.logRepo.updateStatus(logId, 'completed', Date.now())
  }

  async search(query: string, topK: number = 5): Promise<SearchResult[]> {
    if (this.embeddingModel.isAvailable()) {
      try {
        const vectorResults = await this.vectorIndex.search(await this.embeddingModel.encode(query), topK)
        const semanticResults: SearchResult[] = []
        for (const result of vectorResults) {
          const file: FileInfo | null = await this.fileRepo.findById(result.fileId)
          if (file !== null) semanticResults.push({ file: file, score: result.score })
        }
        return semanticResults
      } catch (error) {
        console.warn('Semantic search failed; using lexical search')
      }
    }
    const files: FileInfo[] = await this.fileRepo.findAll()
    const normalized: string = query.toLowerCase()
    return files.map((file: FileInfo): SearchResult => {
      const haystack: string = `${file.name} ${file.contentSummary ?? ''} ${(file.extractedKeywords ?? []).join(' ')}`.toLowerCase()
      const score: number = normalized.length > 0 && haystack.includes(normalized) ? 1 : 0
      return { file: file, score: score }
    }).filter((item: SearchResult) => item.score > 0).slice(0, topK)
  }

  async askQuestion(question: string, topK: number = 5): Promise<QAResult> {
    if (!this.llmService.isConfigured()) throw new Error('LLM service is not configured')
    const results: SearchResult[] = await this.search(question, topK)
    const relevantFiles: RelevantFile[] = []
    const context: RelevantContext[] = []
    for (const result of results) {
      const content: string = limitLeadingText(await this.readFileContent(result.file.path), 1, 1600)
      if (content.length === 0 && (result.file.contentSummary ?? '').length === 0) continue
      const chunks: string[] = chunkText(content.length > 0 ? content : result.file.contentSummary ?? '', 256, 32, 32)
      const snippet: string = chunks.length > 0 ? chunks[0] : ''
      relevantFiles.push({ fileId: result.file.id ?? 0, fileName: result.file.name, similarity: result.score, snippet: snippet })
      context.push({ name: result.file.name, content: snippet })
    }
    const answer: string = await this.llmService.answerQuestion(question, context)
    const confidence: number = relevantFiles.length > 0
      ? relevantFiles.reduce((sum: number, item: RelevantFile) => sum + item.similarity, 0) / relevantFiles.length : 0
    return { answer: answer, relevantFiles: relevantFiles, confidence: confidence }
  }

  async analyzeFile(fileId: number): Promise<FileAnalysisResult> {
    if (!this.llmService.isConfigured()) throw new Error('LLM service is not configured')
    const file: FileInfo | null = await this.fileRepo.findById(fileId)
    if (file === null) throw new Error(`File ${fileId} not found`)
    const content: string = limitLeadingText(await this.readFileContent(file.path))
    return await this.llmService.analyzeFile(file.name, file.type, content, ['工作', '项目', '生活', '灵感', '待整理'])
  }

  async batchAnalyzeFiles(fileIds: number[]): Promise<void> { await this.processBatch(fileIds) }

  private async readFileContent(path: string): Promise<string> {
    try {
      return fs.readTextSync(path, { length: 32000 })
    } catch (error) { return '' }
  }
}
