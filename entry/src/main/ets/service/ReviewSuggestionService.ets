export interface ReviewSuggestion {
  id: string
  fileId: number
  fileName: string
  suggestedCategory: string
  confidence: number
  reason: string
  status: 'pending' | 'accepted' | 'rejected'
  createdTime: number
}

export interface NewSuggestion {
  id: string
  fileId: number
  fileName: string
  suggestedCategory: string
  confidence: number
  reason: string
}

export class ReviewSuggestionService {
  private suggestions: ReviewSuggestion[] = []
  add(suggestion: NewSuggestion): ReviewSuggestion {
    const item: ReviewSuggestion = {
      id: suggestion.id,
      fileId: suggestion.fileId,
      fileName: suggestion.fileName,
      suggestedCategory: suggestion.suggestedCategory,
      confidence: suggestion.confidence,
      reason: suggestion.reason,
      status: 'pending',
      createdTime: Date.now()
    }
    this.suggestions.push(item)
    return item
  }
  listPending(): ReviewSuggestion[] { return this.suggestions.filter((item: ReviewSuggestion) => item.status === 'pending') }
  accept(id: string): boolean { return this.changeStatus(id, 'accepted') }
  reject(id: string): boolean { return this.changeStatus(id, 'rejected') }
  private changeStatus(id: string, status: 'accepted' | 'rejected'): boolean {
    const item = this.suggestions.find((candidate: ReviewSuggestion) => candidate.id === id)
    if (item === undefined) return false
    item.status = status
    return true
  }
}
