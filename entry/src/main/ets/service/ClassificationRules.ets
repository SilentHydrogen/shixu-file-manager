import { FileItem, SmartRule, CategoryItem } from '../data/model/FileBoxTypes'

export function splitRuleKeywords(value: string): string[] {
  return value.replace(/，/g, ',').split(',').map((item: string) => item.trim().toLowerCase())
    .filter((item: string) => item.length > 0)
}

export function fieldMatches(value: string, condition: string): boolean {
  const words = splitRuleKeywords(condition)
  return words.length === 0 || words.some((word: string) => value.toLowerCase().includes(word))
}

export function ruleMatches(file: FileItem, rule: SmartRule): boolean {
  const extension: string = file.extension || file.name.split('.').pop() || ''
  return rule.enabled && (rule.titleKeywords.length > 0 || rule.contentKeywords.length > 0 || rule.formats.length > 0)
    && fieldMatches(file.name, rule.titleKeywords)
    && fieldMatches(file.contentText, rule.contentKeywords)
    && fieldMatches(extension, rule.formats)
}

export function matchingCategories(file: FileItem, rules: SmartRule[], categories: CategoryItem[]): string[] {
  const names = categories.map((category: CategoryItem) => category.name)
  const targets: Set<string> = new Set()
  for (const rule of rules) if (ruleMatches(file, rule) && names.includes(rule.targetTag)) targets.add(rule.targetTag)
  return Array.from(targets)
}

/** Shared category application for rules, manual confirmation and AI tools. */
export function applyCategory(file: FileItem, category: CategoryItem, manual: boolean, ai: boolean = false): FileItem {
  const result = JSON.parse(JSON.stringify(file)) as FileItem
  result.tag = category.name
  result.color = category.color
  result.icon = category.icon
  result.manualTag = manual && category.name !== '待整理'
  result.aiCategory = ai ? category.name : ''
  if (category.name !== '待整理') {
    result.updated = '刚刚归纳'
    if (result.organizedAt === 0) result.organizedAt = Date.now()
  }
  return result
}

export function organizeByRules(file: FileItem, rules: SmartRule[], categories: CategoryItem[], enabled: boolean): FileItem {
  const current = categories.find((category: CategoryItem) => category.name === file.tag)
  if (current !== undefined && file.manualTag && file.tag !== '待整理') return file
  const targets = enabled ? matchingCategories(file, rules, categories) : []
  const keepAI: boolean = targets.length === 0 && file.aiCategory === file.tag && current !== undefined
  const target: string = targets.length === 1 ? targets[0] : keepAI ? file.tag : '待整理'
  const category = categories.find((item: CategoryItem) => item.name === target)
    ?? { name: '待整理', color: '#FFF0DD', icon: '◉', subtitle: '' }
  return applyCategory(file, category, false, keepAI)
}
