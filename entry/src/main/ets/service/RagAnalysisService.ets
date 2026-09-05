import { FileRepository } from '../data/repository/FileRepository'
import { VectorStore } from '../data/vector/VectorStore'
import { VectorIndex } from '../data/vector/VectorIndex'
import { RagAnalysisLogRepository } from '../data/repository/RagAnalysisLogRepository'
import { EmbeddingModel } from '../ai/model/EmbeddingModel'
import { FileInfo } from '../data/model/FileInfo'
import { LLMService } from '../llm/LLMService'
import { FileAnalysisResult, QAResult, RelevantFile, RelevantContext } from '../llm/LLMTypes'
import { chunkText } from '../llm/RagTextUtils'
import { KeywordExpansionService, SUPPORTED_CATEGORIES } from '../ai/KeywordExpansionService'
import { common } from '@kit.AbilityKit'
import fs from '@ohos.file.fs'
import { FileClassificationStore } from './FileClassificationStore'
import { FileItem, CategoryItem, SmartRule } from '../data/model/FileBoxTypes'
import { CategoryLexicon } from '../data/model/CategoryLexicon'
import { fieldMatches } from './ClassificationRules'

export interface CategoryScore {
  category: string
  score: number
  semanticScore?: number
  keywordScore?: number
  recognitionRate?: number
  lexiconSource?: 'preset' | 'user'
}

export interface SearchResult { file: FileInfo; score: number }

export class RagAnalysisService {
  private static instance: RagAnalysisService
  private fileBox: FileClassificationStore | null = null
  private initialization: Promise<void> | null = null
  private fileRepo: FileRepository = new FileRepository()
  private vectorStore: VectorStore = new VectorStore()
  private vectorIndex: VectorIndex = new VectorIndex()
  private logRepo: RagAnalysisLogRepository = new RagAnalysisLogRepository()
  private embeddingModel: EmbeddingModel = new EmbeddingModel()
  private keywordExpansion: KeywordExpansionService = new KeywordExpansionService(this.embeddingModel)
  private llmService: LLMService = LLMService.getInstance()

  static getInstance(): RagAnalysisService {
    if (RagAnalysisService.instance === undefined) RagAnalysisService.instance = new RagAnalysisService()
    return RagAnalysisService.instance
  }

  initialize(context?: common.Context): Promise<void> {
    if (context !== undefined && this.fileBox === null) this.fileBox = new FileClassificationStore(context)
    if (this.initialization === null) this.initialization = this.initializeResources(context)
    return this.initialization
  }

  private async initializeResources(context?: common.Context): Promise<void> {
    try {
      await this.embeddingModel.loadModel(context)
      await this.keywordExpansion.initialize()
      console.info(`Local embedding ready: dimension=${this.embeddingModel.getDimension()}`)
    } catch (error) {
      console.warn(`Local embedding unavailable; lexical search enabled: ${error}`)
    }
    try { await this.vectorIndex.build() } catch (error) {
      console.warn('Vector index unavailable; lexical search enabled')
    }
  }

  async processFile(fileId: number, contentOverride?: string): Promise<void> {
    const file: FileInfo | null = await this.fileRepo.findById(fileId)
    if (file === null) throw new Error(`File ${fileId} not found`)
    const storedContent: string = file.contentSummary ?? ''
    const content: string = contentOverride !== undefined
      ? contentOverride : (storedContent.length > 0 ? storedContent : await this.readFileContent(file.path))
    let summary: string = content.length > 0 ? content.substring(0, 200) : file.name
    let keywords: string[] = file.name.split(/[ ._\-]+/).filter((item: string) => item.length > 0).slice(0, 8)
    keywords = await this.keywordExpansion.expand(keywords)
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
    // Index enrichment is independent of classification; FileOrganizeService owns category decisions.
    await this.fileRepo.markAsProcessed(fileId)
  }

  async localCategoryScores(file: FileItem, categories: CategoryItem[], rules: SmartRule[]): Promise<CategoryScore[]> {
    const result: CategoryScore[] = []
    const lexicons: CategoryLexicon[] = await this.keywordExpansion.syncCategoryLexicons(categories, rules)
    const byCategory: Map<string, CategoryLexicon> = new Map()
    lexicons.forEach((item: CategoryLexicon) => byCategory.set(item.categoryName, item))
    const vector: number[] = this.embeddingModel.isAvailable()
      ? await this.embeddingModel.encode(`${file.name}\n${file.contentText}`) : []
    for (const category of categories) {
      if (category.name === '待整理') continue
      const relevant = rules.filter((rule: SmartRule) => rule.enabled && rule.targetTag === category.name)
      const lexicon = byCategory.get(category.name)
      const semanticScore: number = lexicon === undefined || lexicon.embedding.length === 0
        ? 0 : Math.max(0, Math.min(1, this.cosine(vector, lexicon.embedding)))
      const keywordScore: number = lexicon === undefined ? 0 : this.keywordCoverage(file, lexicon.expandedKeywords)
      let score = this.embeddingModel.isAvailable()
        ? semanticScore * 0.65 + keywordScore * 0.35 : keywordScore
      // A format restriction remains a hard boundary even when keywords expand semantically.
      if (relevant.length > 0 && !relevant.some((rule: SmartRule) => fieldMatches(file.extension, rule.formats))) score = 0
      const bounded = Math.max(0, Math.min(1, score))
      result.push({ category: category.name, score: bounded, semanticScore: semanticScore,
        keywordScore: keywordScore, recognitionRate: bounded, lexiconSource: lexicon?.source })
    }
    return result.sort((a: CategoryScore, b: CategoryScore) => b.score - a.score)
  }

  async processBatch(fileIds: number[]): Promise<void> {
    const ids: number[] = fileIds.slice(0, 20)
    const logId: number = await this.logRepo.createLog(`batch-${Date.now()}`, ids.length)
    let failures = 0
    const errors: string[] = []
    for (const fileId of ids) {
      try { await this.processFile(fileId) } catch (error) {
        failures++; errors.push(`file ${fileId}`); console.error(`Failed to process file ${fileId}`)
      }
    }
    await this.logRepo.updateStatus(logId, failures === 0 ? 'completed' : 'failed', Date.now(), undefined, errors.join(', '))
  }

  async search(query: string, topK: number = 5): Promise<SearchResult[]> {
    if (this.fileBox !== null) {
      for (const file of this.fileBox.files()) await this.fileBox.ensureIndexed(file)
    }
    let semanticResults: SearchResult[] = []
    if (this.embeddingModel.isAvailable()) {
      try {
        const vectorResults = await this.vectorIndex.search(await this.embeddingModel.encode(query), topK)
        semanticResults = []
        for (const result of vectorResults) {
          const file: FileInfo | null = await this.fileRepo.findById(result.fileId)
          if (file !== null) semanticResults.push({ file: file, score: result.score })
        }
      } catch (error) {
        console.warn('Semantic search failed; using lexical search')
      }
    }
    const files: FileInfo[] = await this.fileRepo.findAll()
    const queryTerms = this.tokens(query)
    const nameTerms = queryTerms.filter((term: string) => files.some((file: FileInfo) => file.name.toLowerCase().includes(term)))
    const seeds = [...nameTerms, ...queryTerms].filter((term: string, index: number, all: string[]) => all.indexOf(term) === index)
    const expanded: string[] = await this.keywordExpansion.expand(seeds.slice(0, 16))
    // Bound costly expansion, not the user's original question (whose topic can be near the end).
    const normalized: Set<string> = new Set([...queryTerms, ...expanded].map((item: string) => item.toLowerCase()))
    const lexicalResults = files.map((file: FileInfo): SearchResult => {
      const haystack: string = `${file.name} ${file.contentSummary ?? ''} ${(file.extractedKeywords ?? []).join(' ')}`.toLowerCase()
      const terms = this.tokens(haystack)
      let matches = 0
      for (const queryTerm of normalized) if (terms.includes(queryTerm) || haystack.includes(queryTerm)) matches++
      const score: number = normalized.size > 0 ? matches / normalized.size : 0
      return { file: file, score: score }
    }).filter((item: SearchResult) => item.score > 0).sort((a: SearchResult, b: SearchResult) => b.score - a.score).slice(0, topK)
    const merged: Map<number, SearchResult> = new Map()
    for (const item of semanticResults) merged.set(item.file.id ?? 0, item)
    for (const item of lexicalResults) {
      const id = item.file.id ?? 0
      const existing = merged.get(id)
      merged.set(id, { file: item.file, score: existing === undefined ? item.score * 0.45 : existing.score * 0.7 + item.score * 0.3 })
    }
    return Array.from(merged.values()).sort((a: SearchResult, b: SearchResult) => b.score - a.score).slice(0, topK)
  }

  async askQuestion(question: string, topK: number = 5): Promise<QAResult> {
    if (!this.llmService.isConfigured()) throw new Error('LLM service is not configured')
    const results: SearchResult[] = await this.search(question, topK)
    const relevantFiles: RelevantFile[] = []
    const context: RelevantContext[] = []
    for (const result of results) {
      const extracted = this.fileBox?.files().find((file: FileItem) => file.uri === result.file.uri)
      const content: string = extracted?.contentText ?? result.file.contentSummary ?? ''
      if (content.length === 0 && (result.file.contentSummary ?? '').length === 0) continue
      const chunks: string[] = chunkText(content.length > 0 ? content : result.file.contentSummary ?? '', 256, 32, 160)
      const queryTerms = this.tokens(question)
      chunks.sort((a: string, b: string) => this.chunkScore(b, queryTerms) - this.chunkScore(a, queryTerms))
      const selected: string[] = chunks.slice(0, 3)
      const snippet: string = selected.join('\n')
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
    const content: string = await this.readFileContent(file.path)
    const categories: string[] = this.fileBox?.categories().map((item: CategoryItem) => item.name)
      ?? SUPPORTED_CATEGORIES
    return await this.llmService.analyzeFile(file.name, file.type, content, categories)
  }

  private async readFileContent(path: string): Promise<string> {
    try {
      return fs.readTextSync(path, { length: 32000 })
    } catch (error) { return '' }
  }

  private tokens(value: string): string[] {
    const output: string[] = []
    const parts: string[] = value.toLowerCase().split(/[\s,，。！？；：、/\\._\-]+/)
    for (const part of parts) {
      const segments: string[] = part.match(/[\u4e00-\u9fff]+|[a-z0-9]+/g) ?? []
      for (const segment of segments) {
        if (!/[\u4e00-\u9fff]/.test(segment)) { output.push(segment); continue }
        output.push(segment)
        for (let i = 0; i + 1 < segment.length; i++) output.push(segment.substring(i, i + 2))
      }
    }
    return output.filter((item: string, index: number, all: string[]) => item.length > 0 && all.indexOf(item) === index)
  }

  private chunkScore(chunk: string, terms: string[]): number {
    const tokens = this.tokens(chunk)
    return terms.reduce((score: number, term: string) => score + (tokens.includes(term) ? 1 : 0), 0)
  }

  private keywordCoverage(file: FileItem, keywords: string[]): number {
    const usable = keywords.filter((keyword: string) => keyword.length > 1).slice(0, 48)
    if (usable.length === 0) return 0
    const name = file.name.toLowerCase()
    const content = file.contentText.toLowerCase()
    let evidence = 0
    for (const keyword of usable) {
      if (name.includes(keyword)) evidence += 1.5
      else if (content.includes(keyword)) evidence += 1
    }
    return Math.max(0, Math.min(1, evidence / Math.max(2, Math.min(usable.length, 12))))
  }

  private cosine(left: number[], right: number[]): number {
    if (left.length === 0 || left.length !== right.length) return 0
    let dot = 0
    let leftNorm = 0
    let rightNorm = 0
    for (let index = 0; index < left.length; index++) {
      dot += left[index] * right[index]
      leftNorm += left[index] * left[index]
      rightNorm += right[index] * right[index]
    }
    return dot / ((Math.sqrt(leftNorm) * Math.sqrt(rightNorm)) || 1)
  }

}
