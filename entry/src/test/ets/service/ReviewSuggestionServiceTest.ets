import { describe, it, expect } from '@ohos/hypium'
import { ReviewSuggestionService } from '../../../main/ets/service/ReviewSuggestionService'

export default function reviewSuggestionServiceTest() {
  describe('ReviewSuggestionService', () => {
    it('keeps suggestions pending until explicit decision', 0, () => {
      const service = new ReviewSuggestionService()
      service.add({ id: 'suggestion-1', fileId: 1, fileName: 'note.txt', suggestedCategory: '工作', confidence: 0.8, reason: '关键词命中' })
      expect(service.listPending().length).assertEqual(1)
      expect(service.accept('suggestion-1')).assertTrue()
      expect(service.listPending().length).assertEqual(0)
    })
    it('does not accept unknown suggestion', 0, () => {
      expect(new ReviewSuggestionService().accept('missing')).assertFalse()
    })
  })
}
