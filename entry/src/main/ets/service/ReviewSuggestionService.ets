import preferences from '@ohos.data.preferences'
import { common } from '@kit.AbilityKit'

export interface ReviewSuggestion {
  id: string
  fileId: number
  fileName: string
  suggestedCategory: string
  confidence: number
  reason: string
  status: 'pending' | 'accepted' | 'rejected'
  createdTime: number
  fileUri?: string
  fileFingerprint?: string
  rulesFingerprint?: string
}

export interface NewSuggestion {
  id: string
  fileId: number
  fileName: string
  suggestedCategory: string
  confidence: number
  reason: string
  fileUri?: string
  fileFingerprint?: string
  rulesFingerprint?: string
}

export class ReviewSuggestionService {
  private suggestions: ReviewSuggestion[] = []
  private store: preferences.Preferences | null = null
  async initialize(context: common.Context): Promise<void> {
    this.store = preferences.getPreferencesSync(context, { name: 'review_suggestions' })
    const raw = this.store.getSync('items', '[]') as string
    try { this.suggestions = JSON.parse(raw) as ReviewSuggestion[] } catch (error) { this.suggestions = [] }
  }
  add(suggestion: NewSuggestion): ReviewSuggestion {
    const item: ReviewSuggestion = {
      id: suggestion.id,
      fileId: suggestion.fileId,
      fileName: suggestion.fileName,
      suggestedCategory: suggestion.suggestedCategory,
      confidence: suggestion.confidence,
      reason: suggestion.reason,
      fileUri: suggestion.fileUri,
      fileFingerprint: suggestion.fileFingerprint,
      rulesFingerprint: suggestion.rulesFingerprint,
      status: 'pending',
      createdTime: Date.now()
    }
    this.suggestions = this.suggestions.filter((existing: ReviewSuggestion) =>
      existing.fileId !== suggestion.fileId || existing.status !== 'pending')
    this.suggestions.push(item)
    this.persist()
    return item
  }
  listPending(): ReviewSuggestion[] { return this.suggestions.filter((item: ReviewSuggestion) => item.status === 'pending') }
  async flush(): Promise<void> { if (this.store !== null) await this.store.flush() }
  accept(id: string): boolean { return this.changeStatus(id, 'accepted') }
  reject(id: string): boolean { return this.changeStatus(id, 'rejected') }
  private changeStatus(id: string, status: 'accepted' | 'rejected'): boolean {
    const item = this.suggestions.find((candidate: ReviewSuggestion) => candidate.id === id)
    if (item === undefined) return false
    item.status = status
    this.persist()
    return true
  }
  private persist(): void {
    if (this.store === null) return
    this.store.putSync('items', JSON.stringify(this.suggestions))
    this.store.flush().catch(() => {})
  }
}
