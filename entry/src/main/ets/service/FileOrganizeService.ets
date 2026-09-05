import { common } from '@kit.AbilityKit'
import preferences from '@ohos.data.preferences'
import { FileItem } from '../data/model/FileBoxTypes'
import { DatabaseManager } from '../data/database/DatabaseManager'
import { FileRepository } from '../data/repository/FileRepository'
import { FileAnalysisResult } from '../llm/LLMTypes'
import { LLMService } from '../llm/LLMService'
import { LLMConfigManager } from '../llm/LLMConfig'
import { PrivacyConsentManager } from './PrivacyConsentManager'
import { FileClassificationStore, fileFingerprint, classificationFingerprint } from './FileClassificationStore'
import { matchingCategories } from './ClassificationRules'
import { RagAnalysisService } from './RagAnalysisService'
import { ReviewSuggestionService, ReviewSuggestion } from './ReviewSuggestionService'
import { clampUploadContent } from './ContentBoundary'

export interface OrganizeOutcome { status: 'applied' | 'review' | 'skipped'; category: string; reason: string }
export interface OrganizeBatchResult { applied: number; review: number; skipped: number; failed: number; remaining: number }
export interface ClassificationMetrics {
  attempted: number
  recognized: number
  autoClassified: number
  manualConfirmed: number
  pendingReview: number
  failed: number
  recognitionRate: number
  autoRate: number
  lastUpdated: number
}
interface Attempt { signature: string; completed: boolean; failures: number; retryAt: number }

export class FileOrganizeService {
  private static instance: FileOrganizeService
  private store: FileClassificationStore | null = null
  private attempts: preferences.Preferences | null = null
  private metricsStore: preferences.Preferences | null = null
  private reviews: ReviewSuggestionService = new ReviewSuggestionService()
  private rag: RagAnalysisService = RagAnalysisService.getInstance()
  private llm: LLMService = LLMService.getInstance()
  private running: boolean = false
  private manualPending: boolean = false
  private completion: Promise<void> = Promise.resolve()
  private finishRun: (() => void) | null = null
  private cancelled: boolean = false
  private background: boolean = false
  private continuation: (() => boolean) | undefined = undefined
  private context: common.Context | null = null

  static getInstance(): FileOrganizeService {
    if (FileOrganizeService.instance === undefined) FileOrganizeService.instance = new FileOrganizeService()
    return FileOrganizeService.instance
  }
  async initialize(context: common.Context): Promise<void> {
    if (this.running) return
    this.context = context
    this.store = new FileClassificationStore(context)
    this.attempts = preferences.getPreferencesSync(context, { name: 'classification_jobs' })
    this.metricsStore = preferences.getPreferencesSync(context, { name: 'classification_metrics' })
    await DatabaseManager.getInstance().init(context)
    await LLMConfigManager.getInstance().load(context)
    await PrivacyConsentManager.getInstance().load(context)
    this.llm.reinitialize()
    await this.reviews.initialize(context)
    await this.rag.initialize(context)
  }
  usesLLM(): boolean { return this.llm.isConfigured() && PrivacyConsentManager.getInstance().canUpload() }
  files(): FileItem[] { return this.requireStore().files() }
  pendingReviews(): ReviewSuggestion[] { return this.reviews.listPending() }
  metrics(): ClassificationMetrics {
    const fallback: ClassificationMetrics = { attempted: 0, recognized: 0, autoClassified: 0,
      manualConfirmed: 0, pendingReview: 0, failed: 0, recognitionRate: 0, autoRate: 0, lastUpdated: 0 }
    if (this.metricsStore === null) return fallback
    try {
      const value = this.metricsStore.getSync('summary', JSON.stringify(fallback))
      const parsed = JSON.parse(value as string) as Partial<ClassificationMetrics>
      return {
        attempted: parsed.attempted ?? fallback.attempted,
        recognized: parsed.recognized ?? fallback.recognized,
        autoClassified: parsed.autoClassified ?? fallback.autoClassified,
        manualConfirmed: parsed.manualConfirmed ?? fallback.manualConfirmed,
        pendingReview: parsed.pendingReview ?? fallback.pendingReview,
        failed: parsed.failed ?? fallback.failed,
        recognitionRate: parsed.recognitionRate ?? fallback.recognitionRate,
        autoRate: parsed.autoRate ?? fallback.autoRate,
        lastUpdated: parsed.lastUpdated ?? fallback.lastUpdated
      }
    } catch (error) { return fallback }
  }
  isRunning(): boolean { return this.running || this.manualPending }
  cancelBackground(): void { if (this.background) this.cancel() }
  cancel(): void { this.cancelled = true; this.llm.cancelClassification() }

  async organize(fileId?: number, canContinue?: () => boolean, budgetMs: number = 0): Promise<OrganizeBatchResult> {
    if (this.running && this.background && budgetMs === 0 && !this.manualPending) {
      this.manualPending = true
      this.cancelBackground()
      try { await this.completion } finally { this.manualPending = false }
    }
    if (this.running) throw new Error('文件整理正在运行，请稍候')
    this.running = true
    this.completion = new Promise<void>((resolve) => { this.finishRun = resolve })
    if (typeof AppStorage !== 'undefined') AppStorage.setOrCreate('organizeRunning', true)
    this.cancelled = false
    this.background = budgetMs > 0
    this.continuation = canContinue
    const timeout = budgetMs > 0 ? setTimeout(() => this.cancel(), budgetMs) : -1
    const started = Date.now()
    const result: OrganizeBatchResult = { applied: 0, review: 0, skipped: 0, failed: 0, remaining: 0 }
    try {
      const candidates = this.files().filter((file: FileItem) => fileId === undefined
        ? !file.manualTag && (file.tag === '待整理' || file.tag.length === 0) && this.shouldProcess(file, budgetMs === 0)
        : file.id === fileId)
      result.remaining = candidates.length
      for (const file of candidates) {
        if (this.cancelled || (canContinue !== undefined && !canContinue()) ||
          (budgetMs > 0 && Date.now() - started >= budgetMs)) break
        if (fileId === undefined && result.applied + result.review + result.failed + result.skipped >= 20) break
        const signature = this.jobSignature(file)
        try {
          const outcome = await this.process(file)
          if (outcome.status === 'applied') result.applied++
          else if (outcome.status === 'review') result.review++
          else result.skipped++
          if (outcome.status !== 'skipped') await this.recordMetric(outcome.status)
          await this.recordAttempt(file, signature, true)
        } catch (error) {
          if (this.cancelled || (canContinue !== undefined && !canContinue())) break
          result.failed++
          await this.recordMetric('failed')
          await this.recordAttempt(file, signature, false)
          console.warn('File classification failed; retry state persisted')
          if (fileId !== undefined) throw new Error(error instanceof Error ? error.message : '文件分析失败')
        }
        result.remaining--
      }
      return result
    } finally {
      if (timeout !== -1) clearTimeout(timeout)
      this.running = false; this.background = false; this.continuation = undefined
      if (typeof AppStorage !== 'undefined') AppStorage.setOrCreate('organizeRunning', false)
      if (this.finishRun !== null) this.finishRun()
      this.finishRun = null
    }
  }

  private async process(file: FileItem): Promise<OrganizeOutcome> {
    const store = this.requireStore()
    if (file.manualTag) return { status: 'skipped', category: file.tag, reason: '保留人工分类' }
    const expectedFile = fileFingerprint(file)
    const expectedRules = store.rulesFingerprint()
    const categories = store.categories()
    const matches = matchingCategories(file, store.rules(), categories).filter((name: string) => name !== '待整理')
    const databaseId = await store.ensureIndexed(file)
    const record = await new FileRepository().findById(databaseId)
    if (!record?.isProcessed) await this.rag.processFile(databaseId, file.contentText)
    if (matches.length === 1) {
      await this.apply(file, matches[0], expectedFile, expectedRules, false)
      return { status: 'applied', category: matches[0], reason: '唯一规则命中' }
    }
    if (this.usesLLM()) {
      const retrieved = await this.rag.search(`${file.name} ${file.contentText.slice(0, 180)}`, 6)
      const knownFiles = store.files()
      const examples: string[] = []
      for (const item of retrieved) {
        const known = knownFiles.find((candidate: FileItem) => candidate.uri === item.file.uri)
        if (known === undefined || known.uri === file.uri || known.tag === '待整理' || item.score < 0.45) continue
        if (!categories.some((category) => category.name === known.tag)) continue
        examples.push(JSON.stringify({ name: known.name, category: known.tag,
          excerpt: clampUploadContent(known.contentText).slice(0, 500) }))
        if (examples.length === 3) break
      }
      let applied: OrganizeOutcome | null = null
      await this.llm.classifyFile(file.name, file.kind, file.contentText, categories.map((item) => item.name),
        examples, async (analysis: FileAnalysisResult): Promise<string> => {
          if (applied !== null) return JSON.stringify(applied)
          applied = await this.decide(file, analysis, expectedFile, expectedRules, matches.length > 1, true)
          return JSON.stringify(applied)
        })
      if (applied === null) throw new Error('模型未调用分类工具，请重试或更换支持工具调用的模型')
      return applied
    }
    const scores = await this.rag.localCategoryScores(file, categories, store.rules())
    const top = scores[0]
    const margin: number = top === undefined ? 0 : top.score - (scores[1]?.score ?? 0)
    const analysis: FileAnalysisResult = { summary: '', keywords: [], category: top?.category ?? '待整理',
      confidence: top?.score ?? 0, insufficientContent: top === undefined || margin < 0.08,
      reason: top === undefined ? '本地模型不可用或缺少有效分类，请人工确认' :
        `词库${top.lexiconSource === 'user' ? '（用户定义）' : '（预设）'}：语义 ${((top.semanticScore ?? 0) * 100).toFixed(0)}%，关键词覆盖 ${((top.keywordScore ?? 0) * 100).toFixed(0)}%，综合识别率 ${(top.score * 100).toFixed(0)}%，候选差值 ${(margin * 100).toFixed(0)}%` }
    return this.decide(file, analysis, expectedFile, expectedRules, matches.length > 1, false)
  }

  private async decide(file: FileItem, analysis: FileAnalysisResult, expectedFile: string,
    expectedRules: string, conflict: boolean, remote: boolean): Promise<OrganizeOutcome> {
    if (this.cancelled || (this.continuation !== undefined && !this.continuation())) throw new Error('整理已停止')
    const store = this.requireStore()
    const current = store.files().find((item: FileItem) => item.id === file.id && item.uri === file.uri)
    if (current === undefined || fileFingerprint(current) !== expectedFile || store.rulesFingerprint() !== expectedRules) {
      throw new Error('文件或规则已变化，请重新分析')
    }
    const requested = analysis.suggestedCategory ?? analysis.category
    const valid = store.categories().some((item) => item.name === requested && item.name !== '待整理')
    const category = valid ? requested : '待整理'
    const confidence = Number.isFinite(analysis.confidence) ? Math.min(1, Math.max(0, analysis.confidence ?? 0)) : 0
    const reason = conflict ? `现有规则存在多个目标；${analysis.reason ?? ''}` : analysis.reason ?? '证据不足，请人工确认'
    if (valid && !conflict && !analysis.insufficientContent && confidence >= (remote ? 0.85 : 0.72)) {
      await this.apply(file, category, expectedFile, expectedRules, true)
      return { status: 'applied', category, reason }
    }
    if (this.context !== null) await this.reviews.initialize(this.context)
    this.reviews.add({ id: `${file.id}-${Date.now()}`, fileId: file.id, fileName: file.name,
      fileUri: file.uri, fileFingerprint: expectedFile, rulesFingerprint: expectedRules,
      suggestedCategory: category, confidence, reason })
    await this.reviews.flush()
    return { status: 'review', category, reason }
  }

  private async apply(file: FileItem, category: string, expectedFile: string, expectedRules: string, ai: boolean): Promise<void> {
    if (this.cancelled || (this.continuation !== undefined && !this.continuation())) throw new Error('整理已停止')
    await this.requireStore().classify(file.id, file.uri, category, false, expectedFile, expectedRules, ai)
  }
  async acceptSuggestion(id: string): Promise<void> {
    if (this.context !== null) await this.reviews.initialize(this.context)
    const item = this.reviews.listPending().find((suggestion) => suggestion.id === id)
    if (!item?.fileUri || !item.fileFingerprint || !item.rulesFingerprint) throw new Error('建议已过期，请重新分析')
    await this.requireStore().classify(item.fileId, item.fileUri, item.suggestedCategory, true,
      item.fileFingerprint, item.rulesFingerprint)
    await this.recordMetric('manual')
    this.reviews.accept(id)
    await this.reviews.flush()
  }
  async rejectSuggestion(id: string): Promise<void> {
    if (this.context !== null) await this.reviews.initialize(this.context)
    this.reviews.reject(id)
    await this.reviews.flush()
  }
  private requireStore(): FileClassificationStore {
    if (this.store === null) throw new Error('分类服务尚未初始化')
    return this.store
  }
  private jobSignature(file: FileItem): string {
    const config = LLMConfigManager.getInstance().getConfig()
    return `${fileFingerprint(file)}:${this.requireStore().rulesFingerprint()}:${this.usesLLM()
      ? classificationFingerprint(`${config.baseURL}:${config.model}:${config.protocol}`) : 'local-v1'}`
  }
  private attempt(file: FileItem): Attempt | null {
    try { return JSON.parse(this.attempts?.getSync(`file-${file.id}`, 'null') as string) as Attempt | null }
    catch (error) { return null }
  }
  private shouldProcess(file: FileItem, manual: boolean): boolean {
    const attempt = this.attempt(file)
    return attempt === null || attempt.signature !== this.jobSignature(file) ||
      (!attempt.completed && (manual || Date.now() >= attempt.retryAt))
  }
  private async recordAttempt(file: FileItem, signature: string, completed: boolean): Promise<void> {
    if (this.attempts === null) return
    const previous = this.attempt(file)
    const failures: number = completed ? 0 : (previous?.signature === signature ? previous.failures : 0) + 1
    const attempt: Attempt = { signature, completed, failures,
      retryAt: Date.now() + Math.min(24 * 60, 30 * Math.pow(2, Math.min(failures - 1, 6))) * 60000 }
    this.attempts.putSync(`file-${file.id}`, JSON.stringify(attempt))
    await this.attempts.flush()
  }

  private async recordMetric(kind: 'applied' | 'review' | 'failed' | 'manual'): Promise<void> {
    if (this.metricsStore === null) return
    const metrics = this.metrics()
    if (kind === 'applied') { metrics.attempted++; metrics.recognized++; metrics.autoClassified++ }
    if (kind === 'review') { metrics.attempted++; metrics.pendingReview++ }
    if (kind === 'failed') metrics.failed++
    if (kind === 'manual') { metrics.recognized++; metrics.manualConfirmed++ }
    metrics.recognitionRate = metrics.attempted === 0 ? 0 : metrics.recognized / metrics.attempted
    metrics.autoRate = metrics.attempted === 0 ? 0 : metrics.autoClassified / metrics.attempted
    metrics.lastUpdated = Date.now()
    this.metricsStore.putSync('summary', JSON.stringify(metrics))
    await this.metricsStore.flush()
  }
}
