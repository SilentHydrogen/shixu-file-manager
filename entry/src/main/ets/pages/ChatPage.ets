// entry/src/main/ets/pages/ChatPage.ets

import router from '@ohos.router'
import { ChatInterface } from '../components/ChatInterface'
import { LLMConfigManager } from '../llm/LLMConfig'

@Entry
@Component
struct ChatPage {
  @State isConfigured: boolean = false

  aboutToAppear() {
    this.isConfigured = LLMConfigManager.getInstance().isConfigured()
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

        Text('智能问答')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)

        Button('设置')
          .onClick(() => {
            router.pushUrl({ url: 'pages/LLMConfigPage' })
          })
          .margin({ right: 16 })
      }
      .width('100%')
      .height(56)
      .backgroundColor('#F1F3F5')

      // 内容区域
      if (this.isConfigured) {
        ChatInterface()
      } else {
        Column() {
          Text('🤖')
            .fontSize(64)
            .margin({ bottom: 24 })

          Text('LLM 服务未配置')
            .fontSize(20)
            .fontWeight(FontWeight.Medium)
            .margin({ bottom: 8 })

          Text('请先配置 API Key 以使用智能问答功能')
            .fontSize(14)
            .fontColor('#666666')
            .margin({ bottom: 32 })

          Button('前往配置')
            .width(200)
            .height(44)
            .onClick(() => {
              router.pushUrl({ url: 'pages/LLMConfigPage' })
            })
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#FFFFFF')
  }
}
