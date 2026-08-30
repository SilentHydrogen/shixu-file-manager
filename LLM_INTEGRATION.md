# LLM Integration Documentation

## 概述
已成功集成 OpenAI 兼容的 LLM 服务到 HarmonyOS 文件管理器。

## 实现的功能

### 1. 核心服务层

#### LLMTypes.ets
定义了所有 LLM 相关的类型接口：
- `LLMMessage`: 对话消息
- `LLMRequest`/`LLMResponse`: 请求和响应
- `EmbeddingRequest`/`EmbeddingResponse`: 向量嵌入
- `FileAnalysisResult`: 文件分析结果
- `QAResult`: 问答结果

#### LLMConfig.ets
LLM 配置管理：
- 单例模式配置管理器
- 支持配置 API Key, Base URL, 模型参数
- 默认配置：gpt-3.5-turbo, 2000 tokens, temperature 0.7

#### OpenAIClient.ets
OpenAI API 客户端：
- 使用 `@ohos.net.http` 实现 HTTP 请求
- 支持 Chat Completions API
- 支持 Embeddings API
- 完整的错误处理和超时控制

#### LLMService.ets
高级 LLM 服务：
- `summarizeFile()`: 生成文件摘要
- `extractKeywords()`: 提取关键词
- `categorizeFile()`: 文件分类
- `answerQuestion()`: RAG 问答
- `generateEmbedding()`: 生成向量嵌入
- `batchGenerateEmbeddings()`: 批量生成向量

#### PromptTemplates.ets
提示词模板管理：
- 文件摘要模板
- 关键词提取模板
- 文件分类模板
- RAG 问答模板
- 系统提示词

### 2. RAG 服务增强

#### RagAnalysisService.ets (增强)
新增方法：
- `askQuestion()`: 智能问答，结合向量搜索和 LLM
- `analyzeFile()`: 使用 LLM 分析单个文件
- `batchAnalyzeFiles()`: 批量分析文件
- `generateSummary()`: 集成 LLM 的摘要生成
- `extractKeywords()`: 集成 LLM 的关键词提取
- `generateEmbedding()`: 优先使用 LLM，降级到本地模型
- `readFileContent()`: 读取文件内容工具方法

### 3. UI 组件

#### ChatInterface.ets
聊天界面组件：
- 消息列表显示（用户/助手）
- 实时输入和发送
- 加载状态指示
- 错误提示
- 显示相关文件和相似度
- 自动滚动到最新消息

#### ChatPage.ets
聊天页面：
- 完整的页面布局
- 配置状态检查
- 导航到配置页面
- 未配置时的引导界面

#### LLMConfigPage.ets
LLM 配置页面：
- API Key 输入（密码类型）
- Base URL 配置
- 模型选择
- Max Tokens 滑块（100-4000）
- Temperature 滑块（0-2）
- 保存成功提示
- 使用说明

### 4. 测试

#### PromptTemplatesTest.ets
测试提示词模板：
- 文件摘要提示词生成
- 关键词提取提示词
- 分类提示词
- RAG 问答提示词
- 系统提示词

#### LLMConfigTest.ets
测试配置管理：
- 单例模式
- 默认配置
- 配置更新
- 配置状态检查

#### LLMServiceTest.ets
测试 LLM 服务：
- 单例模式
- 配置状态
- 错误处理

## 架构设计

```
┌─────────────────────────────────────────────┐
│              UI Layer                        │
│  ChatPage, LLMConfigPage, ChatInterface     │
└─────────────────┬───────────────────────────┘
                  │
┌─────────────────▼───────────────────────────┐
│           Service Layer                      │
│  LLMService, RagAnalysisService             │
└─────────────────┬───────────────────────────┘
                  │
┌─────────────────▼───────────────────────────┐
│           Client Layer                       │
│  OpenAIClient (HTTP)                        │
└─────────────────┬───────────────────────────┘
                  │
┌─────────────────▼───────────────────────────┐
│        Configuration Layer                   │
│  LLMConfig, PromptTemplates                 │
└─────────────────────────────────────────────┘
```

## 使用流程

### 1. 配置 LLM
1. 打开应用，进入设置
2. 导航到 LLM 配置页面
3. 输入 OpenAI API Key
4. （可选）修改 Base URL 以使用兼容服务
5. 调整模型参数
6. 保存配置

### 2. 使用智能问答
1. 导航到聊天页面
2. 输入问题
3. 系统自动搜索相关文件
4. LLM 基于文件内容生成答案
5. 显示答案和相关文件

### 3. 文件分析
1. 选择文件
2. 调用分析功能
3. LLM 生成摘要、关键词、分类
4. 保存到数据库

## 数据流

### 智能问答流程
```
用户提问
  ↓
生成问题的向量嵌入
  ↓
向量数据库搜索 (topK=5)
  ↓
读取相关文件内容
  ↓
构建提示词 (问题 + 文件内容)
  ↓
调用 LLM API
  ↓
返回答案 + 相关文件列表
```

### 文件分析流程
```
选择文件
  ↓
读取文件内容
  ↓
并行调用 LLM:
  - 生成摘要
  - 提取关键词
  - 分类
  ↓
保存到数据库
  ↓
生成向量嵌入
  ↓
保存到向量存储
```

## API 兼容性

支持任何兼容 OpenAI API 的服务：
- OpenAI (默认)
- Azure OpenAI
- 本地部署的兼容服务 (如 LocalAI, vLLM)
- 国内 API 提供商 (通义千问、文心一言等，如果提供 OpenAI 兼容接口)

## 配置示例

### OpenAI
```
API Key: sk-xxxxxxxxxxxxxxxxxxxxx
Base URL: https://api.openai.com/v1
Model: gpt-3.5-turbo
```

### Azure OpenAI
```
API Key: your-azure-key
Base URL: https://your-resource.openai.azure.com/openai/deployments/your-deployment
Model: gpt-35-turbo
```

### 本地服务
```
API Key: (可选)
Base URL: http://localhost:8000/v1
Model: llama-2-7b
```

## 错误处理

1. **未配置**: 显示配置引导界面
2. **API 错误**: 显示错误消息，不中断应用
3. **网络超时**: 60秒超时，显示友好提示
4. **文件读取失败**: 记录日志，继续处理其他文件

## 性能优化

1. **批量处理**: 支持批量生成 embeddings
2. **降级策略**: LLM 不可用时使用本地模型
3. **缓存**: 文件摘要和关键词缓存在数据库
4. **超时控制**: 所有 HTTP 请求都有超时限制

## 安全考虑

1. **API Key 保护**: 使用密码输入框
2. **HTTPS**: 默认使用 HTTPS
3. **数据隐私**: 文件内容通过 API 传输时截断（前2000字符）
4. **错误不泄露**: 错误消息不包含敏感信息

## 测试覆盖

- ✅ 配置管理单元测试
- ✅ 提示词模板单元测试
- ✅ LLM 服务单元测试
- ⏳ 集成测试（需要真实 API Key）
- ⏳ UI 测试

## 文件清单

### 核心代码
- `entry/src/main/ets/llm/LLMTypes.ets`
- `entry/src/main/ets/llm/LLMConfig.ets`
- `entry/src/main/ets/llm/OpenAIClient.ets`
- `entry/src/main/ets/llm/LLMService.ets`
- `entry/src/main/ets/llm/PromptTemplates.ets`
- `entry/src/main/ets/service/RagAnalysisService.ets` (增强)

### UI 组件
- `entry/src/main/ets/components/ChatInterface.ets`
- `entry/src/main/ets/pages/ChatPage.ets`
- `entry/src/main/ets/pages/LLMConfigPage.ets`

### 测试文件
- `entry/src/test/ets/llm/PromptTemplatesTest.ets`
- `entry/src/test/ets/llm/LLMConfigTest.ets`
- `entry/src/test/ets/llm/LLMServiceTest.ets`
- `entry/src/test/LocalUnit.test.ets` (更新)

## 后续改进建议

1. **流式输出**: 实现 SSE 流式响应
2. **对话历史**: 保存和加载对话历史
3. **多轮对话**: 支持上下文对话
4. **模型切换**: UI 中动态切换模型
5. **成本统计**: 跟踪 API 调用成本
6. **离线模式**: 完全的本地 LLM 支持
7. **语音输入**: 集成语音转文字
8. **文件预览**: 在聊天中预览文件
9. **导出对话**: 导出聊天记录
10. **RAG 优化**: 改进检索算法和重排序
