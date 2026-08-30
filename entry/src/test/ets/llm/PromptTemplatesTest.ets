// entry/src/test/ets/llm/PromptTemplatesTest.ets

import { describe, it, expect } from '@ohos/hypium'
import { PromptTemplates } from '../../../main/ets/llm/PromptTemplates'

export default function promptTemplatesTest() {
  describe('PromptTemplates', () => {
    it('should generate file summary prompt', 0, () => {
      const prompt = PromptTemplates.fileSummary('test.txt', 'text/plain', 'Hello world')

      expect(prompt).assertContain('test.txt')
      expect(prompt).assertContain('text/plain')
      expect(prompt).assertContain('Hello world')
    })

    it('should generate keyword extraction prompt', 0, () => {
      const prompt = PromptTemplates.extractKeywords('This is a test document about AI')

      expect(prompt).assertContain('关键词')
      expect(prompt).assertContain('This is a test')
    })

    it('should generate categorization prompt', 0, () => {
      const prompt = PromptTemplates.categorizeFile('report.pdf', 'Annual report content')

      expect(prompt).assertContain('report.pdf')
      expect(prompt).assertContain('分类')
    })

    it('should generate RAG QA prompt', 0, () => {
      const files = [
        { name: 'file1.txt', content: 'Content 1' },
        { name: 'file2.txt', content: 'Content 2' }
      ]
      const prompt = PromptTemplates.ragQA('What is in the files?', files)

      expect(prompt).assertContain('file1.txt')
      expect(prompt).assertContain('file2.txt')
      expect(prompt).assertContain('What is in the files?')
    })

    it('should have system prompt', 0, () => {
      const prompt = PromptTemplates.systemPrompt()

      expect(prompt.length).assertLarger(0)
      expect(prompt).assertContain('文件管理助手')
    })
  })
}
