/**
 * One semantic lexicon is maintained for every visible category.
 * The lexicon is rebuilt when the category description or its rules change.
 */
export interface CategoryLexicon {
  categoryName: string
  subtitle: string
  source: 'preset' | 'user'
  seedKeywords: string[]
  expandedKeywords: string[]
  embedding: number[]
  fingerprint: string
  updatedTime: number
}
