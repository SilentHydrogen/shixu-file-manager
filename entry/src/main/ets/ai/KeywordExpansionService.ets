import { EmbeddingModel } from './model/EmbeddingModel'
import { KeywordEmbeddingRepository } from '../data/repository/KeywordEmbeddingRepository'
import { KeywordEmbedding } from '../data/model/KeywordEmbedding'

export const CATEGORY_SYNONYM_GROUPS: Record<string, string[][]> = {
  '工作': [['工作', '办公', 'work'], ['会议', 'meeting'], ['邮件', 'email'], ['报表', '报告', 'report'], ['合同', '协议'], ['客户', '顾客']],
  '项目': [['项目', 'project'], ['需求', 'requirement'], ['开发', '研发', 'development'], ['代码', '源码', 'code'], ['计划', '规划', 'plan'], ['里程碑', 'milestone']],
  '生活': [['生活', '日常', 'life'], ['购物', '采购'], ['账单', '发票', '票据'], ['旅行', '旅游', 'travel'], ['家庭', '家人'], ['健康', '医疗']],
  '灵感': [['灵感', 'inspiration'], ['想法', '点子', 'idea'], ['读书', '阅读'], ['摘录', '引用'], ['创意', '创作'], ['笔记', 'note']],
  '待整理': [['待整理', '未分类', '其他', 'unknown']]
}
export const CATEGORY_KEYWORDS: Record<string, string[]> = {
  '工作': CATEGORY_SYNONYM_GROUPS['工作'].flat(),
  '项目': CATEGORY_SYNONYM_GROUPS['项目'].flat(),
  '生活': CATEGORY_SYNONYM_GROUPS['生活'].flat(),
  '灵感': CATEGORY_SYNONYM_GROUPS['灵感'].flat(),
  '待整理': CATEGORY_SYNONYM_GROUPS['待整理'].flat()
}
export const SUPPORTED_CATEGORIES: string[] = Object.keys(CATEGORY_KEYWORDS)

export class KeywordExpansionService {
  private repository: KeywordEmbeddingRepository = new KeywordEmbeddingRepository()
  private model: EmbeddingModel
  private ready: boolean = false
  constructor(model: EmbeddingModel) { this.model = model }

  async initialize(): Promise<void> {
    if (this.ready || !this.model.isAvailable()) return
    const existing: KeywordEmbedding[] = await this.repository.list()
    const byKeyword: Map<string, KeywordEmbedding> = new Map()
    existing.forEach((item: KeywordEmbedding) => byKeyword.set(item.keyword, item))
    for (const category of Object.keys(CATEGORY_SYNONYM_GROUPS)) {
      for (const synonyms of CATEGORY_SYNONYM_GROUPS[category]) {
        const missing: string[] = synonyms.filter((word: string) => !byKeyword.has(word))
        const vectors: number[][] = await this.model.encodeBatch(missing)
        let vectorIndex: number = 0
        for (const word of synonyms) {
          const old = byKeyword.get(word)
          const embedding: number[] = old === undefined ? vectors[vectorIndex++] : old.embedding
          await this.repository.upsert({ keyword: word, category, synonyms, embedding, updatedTime: Date.now() })
        }
      }
    }
    this.ready = true
  }

  async expand(keywords: string[]): Promise<string[]> {
    const normalized = keywords.map((word: string) => word.toLowerCase()).filter((word: string) => word.length > 0)
    const candidates: KeywordEmbedding[] = await this.repository.list()
    if (!this.model.isAvailable() || candidates.length === 0) return normalized
    const expanded: Set<string> = new Set(normalized)
    for (const keyword of normalized) {
      const vector = await this.model.encode(keyword)
      let best: KeywordEmbedding | null = null
      let score = 0.55
      for (const candidate of candidates) {
        const similarity = this.cosine(vector, candidate.embedding)
        if (similarity > score) { score = similarity; best = candidate }
      }
      if (best !== null) best.synonyms.forEach((word: string) => expanded.add(word))
    }
    return Array.from(expanded)
  }

  async classify(text: string): Promise<string> {
    if (!this.model.isAvailable()) return '待整理'
    const candidates: KeywordEmbedding[] = await this.repository.list()
    if (candidates.length === 0) return '待整理'
    const vector: number[] = await this.model.encode(text)
    let category: string = '待整理'
    let score: number = 0.45
    for (const candidate of candidates) {
      const similarity: number = this.cosine(vector, candidate.embedding)
      if (similarity > score) { score = similarity; category = candidate.category }
    }
    return category
  }
  private cosine(a: number[], b: number[]): number {
    if (a.length !== b.length) return 0
    let dot = 0; let na = 0; let nb = 0
    for (let i = 0; i < a.length; i++) { dot += a[i] * b[i]; na += a[i] * a[i]; nb += b[i] * b[i] }
    return dot / ((Math.sqrt(na) * Math.sqrt(nb)) || 1)
  }
}
