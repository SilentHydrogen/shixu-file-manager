// entry/src/main/ets/llm/PromptTemplates.ets

/**
 * 提示词模板管理
 */
export class PromptTemplates {
  /**
   * 文件摘要提示词
   */
  static fileSummary(fileName: string, fileType: string, content: string): string {
    return `请为以下文件生成简洁的摘要（不超过200字）：

文件名：${fileName}
文件类型：${fileType}
内容：
${content.substring(0, 2000)}

请用中文生成摘要，重点说明文件的主要内容和用途。

摘要：`
  }

  /**
   * 关键词提取提示词
   */
  static extractKeywords(content: string): string {
    return `从以下文本中提取3-5个最重要的关键词：

${content.substring(0, 1000)}

请只返回关键词，用逗号分隔，不要有其他内容。

关键词：`
  }

  /**
   * 文件分类提示词
   */
  static categorizeFile(fileName: string, content: string): string {
    return `请为以下文件选择一个合适的分类：

文件名：${fileName}
内容预览：
${content.substring(0, 500)}

可选分类：文档、代码、图片、视频、音频、压缩包、配置文件、数据文件、其他

请只返回一个分类名称，不要有其他内容。

分类：`
  }

  /**
   * RAG 问答提示词
   */
  static ragQA(question: string, relevantFiles: Array<{ name: string, content: string }>): string {
    const filesContext = relevantFiles
      .map((file, index) => `文件${index + 1}：${file.name}\n内容：${file.content.substring(0, 500)}`)
      .join('\n\n')

    return `你是一个智能文件管理助手。请基于以下相关文件内容回答用户的问题。

相关文件：
${filesContext}

用户问题：${question}

请用中文回答，如果文件内容不足以回答问题，请诚实地说明。

回答：`
  }

  /**
   * 系统提示词
   */
  static systemPrompt(): string {
    return `你是一个智能文件管理助手，专门帮助用户分析和管理文件。你的回答应该：
1. 简洁明了，重点突出
2. 使用中文
3. 基于提供的文件内容
4. 如果信息不足，诚实说明`
  }
}
