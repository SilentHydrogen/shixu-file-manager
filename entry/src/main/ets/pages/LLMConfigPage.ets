import { common } from '@kit.AbilityKit'
import { LLMConfig, LLMConfigManager } from '../llm/LLMConfig'
import { LLMService } from '../llm/LLMService'
import { PrivacyConsentManager } from '../service/PrivacyConsentManager'
import { LLMProtocol } from '../llm/LLMTypes'
import { PiAgentClient } from '../llm/PiAgentClient'
import { describeLLMError, resolveLLMEndpoint } from '../llm/OpenAIClient'

@Entry
@Component
struct LLMConfigPage {
  @State apiKey: string = ''
  @State baseURL: string = 'https://api.openai.com/v1'
  @State model: string = 'gpt-3.5-turbo'
  @State protocol: LLMProtocol = 'auto'
  @State maxTokens: number = 2000
  @State temperature: number = 0.7
  @State status: string = ''
  @State statusError: boolean = false
  @State testing: boolean = false
  @State saving: boolean = false
  @State ready: boolean = false
  @State allowUpload: boolean = false
  private manager: LLMConfigManager = LLMConfigManager.getInstance()

  onPageShow(): void {
    if (!this.ready) this.loadConfiguration()
  }

  private async loadConfiguration(): Promise<void> {
    try {
    const context = getContext(this) as common.UIAbilityContext
    await this.manager.load(context)
    const config = this.manager.getConfig()
    await PrivacyConsentManager.getInstance().load(context)
    this.allowUpload = PrivacyConsentManager.getInstance().canUpload()
    this.apiKey = config.apiKey
    this.baseURL = config.baseURL
    this.model = config.model
    this.protocol = config.protocol
    this.maxTokens = config.maxTokens
    this.temperature = config.temperature
    AppStorage.setOrCreate('llmConfigured', this.manager.isConfigured())
    this.ready = true
    } catch (error) { this.statusError = true; this.status = '配置读取失败，请返回后重试' }
  }

  build() {
    Column() {
      Row() {
        Button('返回').backgroundColor(Color.Transparent).fontColor($r('app.color.text_primary'))
          .onClick(() => this.getUIContext().getRouter().back())
        Text($r('app.string.ai_provider_title')).fontSize(20).fontWeight(FontWeight.Bold).layoutWeight(1)
        Text('LLM').fontSize(12).fontColor($r('app.color.accent_blue'))
      }.width('100%').padding({ left: 8, right: 24 }).height(56)
      Scroll() {
        Column({ space: 16 }) {
          Column({ space: 8 }) {
            Text($r('app.string.ai_provider_intro')).fontSize(23).fontWeight(FontWeight.Bold)
            Text($r('app.string.ai_provider_hint')).fontSize(13).fontColor($r('app.color.text_body'))
          }.width('100%').alignItems(HorizontalAlign.Start).padding({ bottom: 4 })
          Column({ space: 12 }) {
            Text('API 地址').fontSize(14).fontWeight(FontWeight.Medium)
            TextInput({ placeholder: 'https://api.example.com/v1', text: this.baseURL })
              .id('llmBaseURL').onChange((value: string) => this.baseURL = value)
            Text('模型名称').fontSize(14).fontWeight(FontWeight.Medium)
            TextInput({ placeholder: '提供商的模型 ID', text: this.model })
              .id('llmModel').onChange((value: string) => this.model = value)
            Text('API Key').fontSize(14).fontWeight(FontWeight.Medium)
            TextInput({ placeholder: '输入 API Key', text: this.apiKey }).type(InputType.Password)
              .id('llmApiKey').onChange((value: string) => this.apiKey = value)
            Text('API 协议').fontSize(14).fontWeight(FontWeight.Medium)
            Select([{ value: '自动识别' }, { value: 'Chat Completions' }, { value: 'Responses' }])
              .selected(this.protocol === 'responses' ? 2 : this.protocol === 'chat_completions' ? 1 : 0)
              .value(this.protocol === 'responses' ? 'Responses' : this.protocol === 'chat_completions' ? 'Chat Completions' : '自动识别')
              .onSelect((index: number) => this.protocol = index === 2 ? 'responses' : index === 1 ? 'chat_completions' : 'auto')
            Text($r('app.string.ai_endpoint_hint')).fontSize(12).fontColor($r('app.color.text_caption'))
          }.width('100%').alignItems(HorizontalAlign.Start).padding(20)
            .backgroundColor($r('app.color.card_bg')).borderRadius(20).enabled(this.ready && !this.testing && !this.saving)
          if (this.status.length > 0) {
            Text(this.status).id('llmConnectionStatus').fontSize(14)
              .fontColor(this.statusError ? $r('app.color.accent_red') : $r('app.color.accent_green'))
              .width('100%').padding(16).backgroundColor($r('app.color.card_bg')).borderRadius(16)
          }
          Row({ space: 12 }) {
            Button(this.testing ? '测试中…' : '测试连接').id('llmTestConnection').layoutWeight(1)
              .backgroundColor($r('app.color.tint_blue_strong')).fontColor($r('app.color.accent_blue'))
              .enabled(this.ready && !this.testing && !this.saving).onClick(() => this.testConnection())
            Button(this.saving ? '保存中…' : '保存配置').id('llmSaveConfig').layoutWeight(1)
              .backgroundColor($r('app.color.accent_primary')).fontColor(Color.White)
              .enabled(this.ready && !this.testing && !this.saving).onClick(() => this.save())
          }.width('100%')
          Column({ space: 12 }) {
            Text($r('app.string.ai_generation_settings')).fontSize(16).fontWeight(FontWeight.Medium)
            Text(`最大输出 Tokens：${this.maxTokens}`).fontSize(13)
            Slider({ value: this.maxTokens, min: 100, max: 4000, step: 100 }).onChange((value: number) => this.maxTokens = value)
            Text(`Temperature：${this.temperature.toFixed(1)}`).fontSize(13)
            Slider({ value: this.temperature, min: 0, max: 2, step: 0.1 }).onChange((value: number) => this.temperature = value)
          }.width('100%').alignItems(HorizontalAlign.Start).padding(20)
            .backgroundColor($r('app.color.card_bg')).borderRadius(20).enabled(!this.testing && !this.saving)
          Column({ space: 12 }) {
            Text($r('app.string.ai_content_permission')).fontSize(16).fontWeight(FontWeight.Medium)
            Text($r('app.string.ai_content_permission_hint')).fontSize(13).fontColor($r('app.color.text_body'))
            Button(this.allowUpload ? '撤销文件片段授权' : '同意发送文件片段').width('100%')
              .fontColor($r('app.color.accent_blue')).backgroundColor($r('app.color.tint_blue_strong'))
              .enabled(this.ready && !this.saving).onClick(() => this.toggleUploadConsent())
            Text(this.allowUpload ? '当前：已授权' : '当前：未授权').fontSize(12).fontColor($r('app.color.text_caption'))
          }.width('100%').alignItems(HorizontalAlign.Start).padding(20)
            .backgroundColor($r('app.color.card_bg')).borderRadius(20)
          Button('清除 API Key').width('100%').fontColor($r('app.color.accent_red'))
            .backgroundColor(Color.Transparent).enabled(this.ready && !this.testing && !this.saving).onClick(() => this.clearKey())
        }.width('100%').padding(20)
      }.layoutWeight(1).width('100%')
    }.width('100%').height('100%').backgroundColor($r('app.color.page_bg'))
  }

  private draft(): LLMConfig {
    return { apiKey: this.apiKey.trim(), baseURL: this.baseURL.trim(), model: this.model.trim(), protocol: this.protocol,
      maxTokens: this.maxTokens, temperature: this.temperature }
  }

  private validate(): boolean {
    try {
      if (this.apiKey.trim().length === 0) throw new Error('请先输入 API Key')
      if (this.model.trim().length === 0) throw new Error('请先输入模型名称')
      resolveLLMEndpoint(this.baseURL, this.protocol)
      return true
    } catch (error) { this.statusError = true; this.status = describeLLMError(error); return false }
  }

  private updateManager(): void {
    this.manager.updateConfig({ apiKey: this.apiKey, baseURL: this.baseURL, model: this.model, protocol: this.protocol, maxTokens: this.maxTokens, temperature: this.temperature })
  }

  private async save(): Promise<void> {
    if (this.saving || !this.validate()) return
    this.saving = true
    const previous = this.manager.getConfig()
    this.updateManager()
    try {
      const context = getContext(this) as common.UIAbilityContext
      await this.manager.persist(context)
      LLMService.getInstance().reinitialize()
      AppStorage.setOrCreate('llmConfigured', this.manager.isConfigured())
      this.statusError = false
      this.status = '配置已保存，无需重启即可使用'
    } catch (error) {
      this.statusError = true
      this.manager.updateConfig(previous)
      LLMService.getInstance().reinitialize()
      this.status = '保存失败：系统安全存储不可用，请重试'
    } finally { this.saving = false }
  }

  private async testConnection(): Promise<void> {
    if (this.testing || !this.validate()) return
    this.testing = true
    this.statusError = false
    this.status = '正在测试连接…'
    try {
      await new PiAgentClient(this.draft()).chat({ messages: [{ role: 'user', content: '请回复：连接成功' }] })
      this.status = '连接成功，请保存配置后使用'
    } catch (error) {
      this.statusError = true
      this.status = describeLLMError(error)
    } finally {
      this.testing = false
    }
  }

  private async toggleUploadConsent(): Promise<void> {
    const context = getContext(this) as common.UIAbilityContext
    try {
      const allowed = !this.allowUpload
      await PrivacyConsentManager.getInstance().setConsent(context, allowed)
      this.allowUpload = allowed
      this.statusError = false
      this.status = this.allowUpload ? '已允许发送受限文件片段' : '已撤销上传许可'
    } catch (error) {
      this.statusError = true
      this.status = '隐私设置保存失败'
    }
  }

  private async clearKey(): Promise<void> {
    try {
      await this.manager.clearApiKey(getContext(this) as common.UIAbilityContext)
      this.apiKey = ''
      LLMService.getInstance().reinitialize()
      AppStorage.setOrCreate('llmConfigured', false)
      this.statusError = false
      this.status = 'API Key 已清除'
    } catch (error) {
      this.statusError = true
      this.status = '清除失败'
    }
  }
}
