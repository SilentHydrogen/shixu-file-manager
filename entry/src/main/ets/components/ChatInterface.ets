// entry/src/main/ets/components/ChatInterface.ets

import { RagAnalysisService } from '../service/RagAnalysisService'
import { QAResult, RelevantFile, LLMMessage } from '../llm/LLMTypes'

import { LLMService } from '../llm/LLMService'
import { describeLLMError } from '../llm/OpenAIClient'

interface RelevantFileRef {
  fileId: number
  fileName: string
  similarity: number
}
interface ChatMessage {
  id: number
  mode: boolean
  role: 'user' | 'assistant'
  content: string
  timestamp: number
  relevantFiles?: RelevantFileRef[]
}

@Component
export struct ChatInterface {
  @Prop useFiles: boolean = true
  private nextMessageId: number = 0
  @State retryText: string = ''
  @State messages: ChatMessage[] = []
  @State inputText: string = ''
  @State isLoading: boolean = false
  @State errorMessage: string = ''
  // Reuse singleton initialized by EntryAbility so local embedding/vector index stay available.
  private ragService: RagAnalysisService = RagAnalysisService.getInstance()
  private scroller: Scroller = new Scroller()

  build() {
    Column() {
      if (this.messages.filter((message: ChatMessage) => message.mode === this.useFiles).length === 0) {
        Column({ space: 12 }) {
          Text(this.useFiles ? $r('app.string.ai_chat_welcome') : $r('app.string.ai_chat_plain_welcome'))
            .fontSize(24).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_primary'))
          Text(this.useFiles ? $r('app.string.ai_chat_hint') : $r('app.string.ai_chat_plain_hint'))
            .fontSize(14).fontColor($r('app.color.text_body'))
          if (this.useFiles) {
            Button($r('app.string.ai_chat_example_work')).fontSize(13)
              .backgroundColor($r('app.color.card_bg')).fontColor($r('app.color.accent_blue'))
              .onClick(() => this.inputText = '帮我查找与工作相关的文件')
            Button($r('app.string.ai_chat_example_study')).fontSize(13)
              .backgroundColor($r('app.color.card_bg')).fontColor($r('app.color.accent_blue'))
              .onClick(() => this.inputText = '学习资料里有哪些重要内容？')
          }
        }.width('100%').alignItems(HorizontalAlign.Start).padding(24)
      }
      // 聊天消息列表
      List({ scroller: this.scroller }) {
        ForEach(this.messages.filter((message: ChatMessage) => message.mode === this.useFiles), (message: ChatMessage) => {
          ListItem() {
            this.MessageBubble(message)
          }
          .margin({ bottom: 12 })
        }, (message: ChatMessage) => `${message.id}`)
      }
      .layoutWeight(1)
      .padding({ left: 16, right: 16, top: 16 })
      .scrollBar(BarState.Auto)

      // 加载指示器
      if (this.isLoading) {
        Row() {
          LoadingProgress()
            .width(24)
            .height(24)
            .margin({ right: 8 })
          Text('正在思考...')
            .fontSize(14)
            .fontColor('#999999')
        }
        .padding(12)
      }

      // 错误提示
      if (this.errorMessage) {
        Row() {
          Text(this.errorMessage)
            .fontSize(14)
            .fontColor(Color.Red)
            .layoutWeight(1)
          Button('重试').enabled(!this.isLoading).onClick(() => {
            this.inputText = this.retryText
            this.sendMessage()
          })
        }
        .padding(12)
        .width('100%')
        .backgroundColor('#FFF0F0')
      }

      // 输入框
      Row() {
        TextInput({ placeholder: this.useFiles ? '问问你的文件…' : '输入消息…', text: this.inputText }).id('chatInput')
          .layoutWeight(1)
          .onChange((value: string) => {
            this.inputText = value
          })
          .onSubmit(() => {
            this.sendMessage()
          })

        Button('发送').id('chatSend').backgroundColor($r('app.color.accent_primary'))
          .width(80)
          .height(40)
          .margin({ left: 8 })
          .enabled(!this.isLoading && this.inputText.trim().length > 0)
          .onClick(() => {
            this.sendMessage()
          })
      }
      .padding(16)
      .backgroundColor($r('app.color.card_bg'))
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  MessageBubble(message: ChatMessage) {
    Column() {
      Row() {
        if (message.role === 'user') {
          Blank().layoutWeight(1)
          Column() {
            Text(message.content)
              .fontSize(15)
              .fontColor('#FFFFFF')
              .padding(12)
              .backgroundColor($r('app.color.accent_blue'))
              .borderRadius(12)
              .maxLines(100)
          }
          .alignItems(HorizontalAlign.End)
          .constraintSize({ maxWidth: '88%' })
        } else {
          Column() {
            Text(message.content)
              .fontSize(15)
              .fontColor('#000000')
              .padding(12)
              .backgroundColor($r('app.color.card_bg'))
              .borderRadius(12)
              .maxLines(100)

            // 显示相关文件
            if (message.relevantFiles && message.relevantFiles.length > 0) {
              Column({ space: 4 }) {
                Text('相关文件：')
                  .fontSize(12)
                  .fontColor('#666666')
                  .margin({ top: 8 })

                ForEach(message.relevantFiles, (file: RelevantFileRef) => {
                  Row() {
                    Text(`📄 ${file.fileName}`)
                      .fontSize(12)
                      .fontColor('#007AFF')
                      .layoutWeight(1)
                    Text(`${(file.similarity * 100).toFixed(0)}%`)
                      .fontSize(11)
                      .fontColor('#999999')
                  }
                  .width('100%')
                }, (file: RelevantFileRef) => `${file.fileId}-${file.fileName}`)
              }
              .alignItems(HorizontalAlign.Start)
              .padding({ top: 4, left: 12, right: 12, bottom: 8 })
            }
          }
          .alignItems(HorizontalAlign.Start)
          .constraintSize({ maxWidth: '88%' })

          Blank().layoutWeight(1)
        }
      }
      .width('100%')

      // 时间戳
      Text(this.formatTimestamp(message.timestamp))
        .fontSize(11)
        .fontColor('#999999')
        .margin({ top: 4 })
        .alignSelf(message.role === 'user' ? ItemAlign.End : ItemAlign.Start)
    }
    .width('100%')
  }

  private async sendMessage() {
    if (this.inputText.trim().length === 0 || this.isLoading) {
      return
    }

    const mode = this.useFiles
    const userMessage: ChatMessage = {
      id: ++this.nextMessageId,
      mode: mode,
      role: 'user',
      content: this.inputText.trim(),
      timestamp: Date.now()
    }

    this.messages.push(userMessage)
    this.inputText = ''
    this.errorMessage = ''
    this.isLoading = true

    // 滚动到底部
    setTimeout(() => {
      this.scroller.scrollEdge(Edge.Bottom)
    }, 100)

    try {
      // 调用 RAG 服务
      const history: LLMMessage[] = this.messages.filter((message: ChatMessage) => message.mode === mode)
        .slice(-12).map((message: ChatMessage): LLMMessage => ({ role: message.role, content: message.content }))
      const result: QAResult = mode ? await this.ragService.askQuestion(userMessage.content) : {
        answer: (await LLMService.getInstance().generate({ messages: history })).content,
        relevantFiles: [], confidence: 0
      }

      const assistantMessage: ChatMessage = {
        id: ++this.nextMessageId,
        mode: mode,
        role: 'assistant',
        content: result.answer,
        timestamp: Date.now(),
        relevantFiles: result.relevantFiles.map((f: RelevantFile): RelevantFileRef => {
          const ref: RelevantFileRef = {
            fileId: f.fileId,
            fileName: f.fileName,
            similarity: f.similarity
          }
          return ref
        })
      }

      this.messages.push(assistantMessage)

      // 滚动到底部
      setTimeout(() => {
        this.scroller.scrollEdge(Edge.Bottom)
      }, 100)

    } catch (err) {
      this.errorMessage = describeLLMError(err)
      this.retryText = userMessage.content
      this.messages = this.messages.filter((message: ChatMessage) => message.id !== userMessage.id)
    } finally {
      this.isLoading = false
    }
  }

  private formatTimestamp(timestamp: number): string {
    const date = new Date(timestamp)
    const hours = date.getHours().toString().padStart(2, '0')
    const minutes = date.getMinutes().toString().padStart(2, '0')
    return `${hours}:${minutes}`
  }
}
