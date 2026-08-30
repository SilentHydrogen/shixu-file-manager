// entry/src/main/ets/pages/LLMConfigPage.ets

import router from '@ohos.router'
import { LLMConfigManager } from '../llm/LLMConfig'

@Entry
@Component
struct LLMConfigPage {
  @State apiKey: string = ''
  @State baseURL: string = 'https://api.openai.com/v1'
  @State model: string = 'gpt-3.5-turbo'
  @State maxTokens: number = 2000
  @State temperature: number = 0.7
  @State showSuccess: boolean = false

  aboutToAppear() {
    const config = LLMConfigManager.getInstance().getConfig()
    this.apiKey = config.apiKey
    this.baseURL = config.baseURL ?? 'https://api.openai.com/v1'
    this.model = config.model
    this.maxTokens = config.maxTokens
    this.temperature = config.temperature
  }

  build() {
    Column() {
      // 标题栏
      Row() {
        Button('返回')
          .onClick(() => {
            router.back()
          })
          .margin({ left: 16 })

        Text('LLM 配置')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)

        Blank()
          .width(80)
      }
      .width('100%')
      .height(56)
      .backgroundColor('#F1F3F5')

      Scroll() {
        Column({ space: 16 }) {
          // API Key
          Column({ space: 8 }) {
            Text('API Key')
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
            TextInput({ placeholder: '请输入 OpenAI API Key', text: this.apiKey })
              .type(InputType.Password)
              .onChange((value: string) => {
                this.apiKey = value
              })
          }
          .alignItems(HorizontalAlign.Start)
          .width('100%')

          // Base URL
          Column({ space: 8 }) {
            Text('Base URL')
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
            TextInput({ placeholder: 'API 地址', text: this.baseURL })
              .onChange((value: string) => {
                this.baseURL = value
              })
          }
          .alignItems(HorizontalAlign.Start)
          .width('100%')

          // Model
          Column({ space: 8 }) {
            Text('模型')
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
            TextInput({ placeholder: '模型名称', text: this.model })
              .onChange((value: string) => {
                this.model = value
              })
          }
          .alignItems(HorizontalAlign.Start)
          .width('100%')

          // Max Tokens
          Column({ space: 8 }) {
            Text(`最大 Tokens: ${this.maxTokens}`)
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
            Slider({
              value: this.maxTokens,
              min: 100,
              max: 4000,
              step: 100
            })
              .onChange((value: number) => {
                this.maxTokens = value
              })
          }
          .alignItems(HorizontalAlign.Start)
          .width('100%')

          // Temperature
          Column({ space: 8 }) {
            Text(`Temperature: ${this.temperature.toFixed(1)}`)
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
            Slider({
              value: this.temperature,
              min: 0,
              max: 2,
              step: 0.1
            })
              .onChange((value: number) => {
                this.temperature = value
              })
          }
          .alignItems(HorizontalAlign.Start)
          .width('100%')

          // 保存按钮
          Button('保存配置')
            .width('100%')
            .height(48)
            .fontSize(16)
            .onClick(() => {
              this.saveConfig()
            })

          // 成功提示
          if (this.showSuccess) {
            Text('✓ 配置已保存')
              .fontSize(14)
              .fontColor(Color.Green)
          }

          // 说明文本
          Column({ space: 8 }) {
            Text('说明：')
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
            Text('1. API Key 从 OpenAI 官网获取')
              .fontSize(12)
              .fontColor('#666666')
            Text('2. 支持兼容 OpenAI API 的其他服务')
              .fontSize(12)
              .fontColor('#666666')
            Text('3. Temperature 越高，输出越随机')
              .fontSize(12)
              .fontColor('#666666')
          }
          .alignItems(HorizontalAlign.Start)
          .width('100%')
          .padding(16)
          .backgroundColor('#F8F9FA')
          .borderRadius(8)
        }
        .padding(16)
      }
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#FFFFFF')
  }

  private saveConfig() {
    LLMConfigManager.getInstance().updateConfig({
      apiKey: this.apiKey,
      baseURL: this.baseURL,
      model: this.model,
      maxTokens: this.maxTokens,
      temperature: this.temperature
    })

    this.showSuccess = true
    setTimeout(() => {
      this.showSuccess = false
    }, 2000)
  }
}
