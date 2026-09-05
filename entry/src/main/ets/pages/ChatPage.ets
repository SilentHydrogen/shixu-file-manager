import { common } from '@kit.AbilityKit'
import { ChatInterface } from '../components/ChatInterface'
import { LLMConfigManager } from '../llm/LLMConfig'
import { PrivacyConsentManager } from '../service/PrivacyConsentManager'
import { LLMService } from '../llm/LLMService'

@Entry
@Component
struct ChatPage {
  @StorageLink('llmConfigured') isConfigured: boolean = false
  @State useFiles: boolean = true
  @State hasConsent: boolean = false

  onPageShow(): void {
    this.refreshConfiguration()
  }

  private async refreshConfiguration(): Promise<void> {
    try {
    const manager = LLMConfigManager.getInstance()
    const context = getContext(this) as common.UIAbilityContext
    await manager.load(context)
    await PrivacyConsentManager.getInstance().load(context)
    this.isConfigured = manager.isConfigured()
    this.hasConsent = PrivacyConsentManager.getInstance().canUpload()
    LLMService.getInstance().reinitialize()
    } catch (error) { this.isConfigured = false }
  }

  build() {
    Column() {
      Row() {
        Button('返回').onClick(() => this.getUIContext().getRouter().back()).margin({ left: 16 })
        Text('文件问答').fontSize(20).fontWeight(FontWeight.Bold).layoutWeight(1).textAlign(TextAlign.Center)
        Button('设置').onClick(() => this.getUIContext().getRouter().pushUrl({ url: 'pages/LLMConfigPage' })).margin({ right: 16 })
      }
      .width('100%').height(56).backgroundColor($r('app.color.page_bg'))
      Row({ space: 12 }) {
        Button($r('app.string.ai_chat_mode_files')).layoutWeight(1)
          .fontColor(this.useFiles ? Color.White : $r('app.color.text_body'))
          .backgroundColor(this.useFiles ? $r('app.color.accent_primary') : $r('app.color.card_bg'))
          .onClick(() => this.useFiles = true)
        Button($r('app.string.ai_chat_mode_plain')).layoutWeight(1)
          .fontColor(!this.useFiles ? Color.White : $r('app.color.text_body'))
          .backgroundColor(!this.useFiles ? $r('app.color.accent_primary') : $r('app.color.card_bg'))
          .onClick(() => this.useFiles = false)
      }.width('100%').padding({ left: 20, right: 20, top: 8, bottom: 12 })
      if (this.isConfigured && (!this.useFiles || this.hasConsent)) {
        ChatInterface({ useFiles: this.useFiles }).layoutWeight(1)
      } else {
        Column() {
          Text('🤖').fontSize(64).margin({ bottom: 24 })
          Text(this.isConfigured ? '需要隐私授权' : 'LLM 服务未配置').fontSize(20).fontWeight(FontWeight.Medium).margin({ bottom: 8 })
          Text(this.isConfigured ? '请阅读隐私说明并授权发送受限文件片段' : '请先配置 Chat API Key 以使用智能问答功能').fontSize(14).fontColor('#666666').margin({ bottom: 32 })
          Button('前往配置').width(200).height(44).onClick(() => this.getUIContext().getRouter().pushUrl({ url: 'pages/LLMConfigPage' }))
        }
        .width('100%').layoutWeight(1).justifyContent(FlexAlign.Center).padding(24)
      }
    }
    .width('100%').height('100%').backgroundColor($r('app.color.page_bg'))
  }
}
