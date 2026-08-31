// entry/src/main/ets/components/ChatInterface.ets

import { RagAnalysisService } from '../service/RagAnalysisService'
import { QAResult, RelevantFile } from '../llm/LLMTypes'

interface RelevantFileRef {
  fileName: string
  similarity: number
}

interface ChatMessage {
  role: 'user' | 'assistant'
  content: string
  timestamp: number
  relevantFiles?: RelevantFileRef[]
}

@Component
export struct ChatInterface {
  @State messages: ChatMessage[] = []
  @State inputText: string = ''
  @State isLoading: boolean = false
  @State errorMessage: string = ''
  private ragService: RagAnalysisService = new RagAnalysisService()
  private scroller: Scroller = new Scroller()

  build() {
    Column() {
      // 聊天消息列表
      List({ scroller: this.scroller }) {
        ForEach(this.messages, (message: ChatMessage, index: number) => {
          ListItem() {
            this.MessageBubble(message)
          }
          .margin({ bottom: 12 })
        }, (message: ChatMessage, index: number) => `${index}_${message.timestamp}`)
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
          Text(`❌ ${this.errorMessage}`)
            .fontSize(14)
            .fontColor(Color.Red)
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .padding(12)
        .width('100%')
        .backgroundColor('#FFF0F0')
      }

      // 输入框
      Row() {
        TextInput({ placeholder: '输入问题...', text: this.inputText })
          .layoutWeight(1)
          .onChange((value: string) => {
            this.inputText = value
          })
          .onSubmit(() => {
            this.sendMessage()
          })

        Button('发送')
          .width(80)
          .height(40)
          .margin({ left: 8 })
          .enabled(!this.isLoading && this.inputText.trim().length > 0)
          .onClick(() => {
            this.sendMessage()
          })
      }
      .padding(16)
      .backgroundColor('#F8F9FA')
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
              .backgroundColor('#007AFF')
              .borderRadius(12)
              .maxLines(100)
          }
          .alignItems(HorizontalAlign.End)
          .constraintSize({ maxWidth: '70%' })
        } else {
          Column() {
            Text(message.content)
              .fontSize(15)
              .fontColor('#000000')
              .padding(12)
              .backgroundColor('#E9ECEF')
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
                })
              }
              .alignItems(HorizontalAlign.Start)
              .padding({ top: 4, left: 12, right: 12, bottom: 8 })
            }
          }
          .alignItems(HorizontalAlign.Start)
          .constraintSize({ maxWidth: '70%' })

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

    const userMessage: ChatMessage = {
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
      const result: QAResult = await this.ragService.askQuestion(userMessage.content)

      const assistantMessage: ChatMessage = {
        role: 'assistant',
        content: result.answer,
        timestamp: Date.now(),
        relevantFiles: result.relevantFiles.map((f: RelevantFile): RelevantFileRef => {
          const ref: RelevantFileRef = {
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
      this.errorMessage = `错误: ${JSON.stringify(err)}`
      console.error('Chat error:', JSON.stringify(err))
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
