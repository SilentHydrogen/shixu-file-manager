import { FileAnalysisResult } from './LLMTypes'

export interface StructuredFileAnalysis extends FileAnalysisResult {
  suggestedCategory: string
  confidence: number
  reason: string
  insufficientContent: boolean
}

export function parseFileAnalysis(content: string): StructuredFileAnalysis {
  const jsonText: string = content.trim()
    .replace(/^```(?:json)?\s*/i, '')
    .replace(/\s*```$/, '')
  let value: Object
  try {
    value = JSON.parse(jsonText) as Object
  } catch (error) {
    throw new Error('LLM response is not valid JSON')
  }
  const data: Record<string, Object> = value as Record<string, Object>
  if (typeof data.summary !== 'string'
    || !Array.isArray(data.keywords)
    || typeof data.suggestedCategory !== 'string'
    || typeof data.confidence !== 'number'
    || typeof data.reason !== 'string'
    || typeof data.insufficientContent !== 'boolean') {
    throw new Error('LLM response is missing required analysis fields')
  }
  const keywords: string[] = (data.keywords as Object[])
    .filter((item: Object) => typeof item === 'string')
    .map((item: Object) => item as string)
    .filter((item: string) => item.trim().length > 0)
  return {
    summary: data.summary as string,
    keywords: keywords,
    category: data.suggestedCategory as string,
    suggestedCategory: data.suggestedCategory as string,
    confidence: Math.max(0, Math.min(1, data.confidence as number)),
    reason: data.reason as string,
    insufficientContent: data.insufficientContent as boolean
  }
}
