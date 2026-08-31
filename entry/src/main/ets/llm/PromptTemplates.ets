import { RelevantContext } from './LLMTypes'

export class PromptTemplates {
  static fileSummary(fileName: string, fileType: string, content: string): string {
    return `请为以下文件生成简洁摘要（不超过200字）：\n文件名：${fileName}\n文件类型：${fileType}\n内容：\n${content.substring(0, 8000)}\n请用中文回答。`
  }
  static extractKeywords(content: string): string {
    return `从以下文本提取3-5个最重要关键词，只返回逗号分隔结果：\n${content.substring(0, 8000)}`
  }
  static categorizeFile(fileName: string, content: string): string {
    return `请为文件选择分类，只返回一个分类名称。\n文件名：${fileName}\n内容：${content.substring(0, 8000)}\n可选：文档、代码、图片、视频、音频、压缩包、配置文件、数据文件、其他`
  }
  static analyzeFile(fileName: string, fileType: string, content: string, categories: string[]): string {
    return `请分析文件并严格只返回 JSON，不要 Markdown：{"summary":"摘要","keywords":["关键词"],"suggestedCategory":"可选分类","confidence":0.0,"reason":"理由","insufficientContent":false}\n文件名：${fileName}\n文件类型：${fileType}\n可选分类：${categories.join('、')}\n本地提取内容：\n${content.substring(0, 8000)}\n未知分类返回“待整理”。`
  }
  static ragQA(question: string, relevantFiles: RelevantContext[]): string {
    const context: string = relevantFiles.map((file, index) => `文件${index + 1}：${file.name}\n内容：${file.content.substring(0, 1600)}`).join('\n\n')
    return `请基于相关文件回答问题。资料不足时明确说明，不要猜测。\n相关文件：\n${context}\n用户问题：${question}`
  }
  static systemPrompt(): string {
    return '你是智能文件管理助手。使用中文，基于给定文件内容回答，信息不足时诚实说明。'
  }
}
