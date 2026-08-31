import router from '@ohos.router'
import { common } from '@kit.AbilityKit'
import { LLMConfigManager } from '../llm/LLMConfig'
import { LLMService } from '../llm/LLMService'
import { PrivacyConsentManager } from '../service/PrivacyConsentManager'

@Entry
@Component
struct LLMConfigPage {
  @State apiKey: string = ''
  @State baseURL: string = 'https://api.openai.com/v1'
  @State model: string = 'gpt-3.5-turbo'
  @State maxTokens: number = 2000
  @State temperature: number = 0.7
  @State status: string = ''
  @State statusError: boolean = false
  @State testing: boolean = false
  @State allowUpload: boolean = false
  private manager: LLMConfigManager = LLMConfigManager.getInstance()

  async aboutToAppear(): Promise<void> {
    const context = getContext(this) as common.UIAbilityContext
    await this.manager.load(context)
    const config = this.manager.getConfig()
    await PrivacyConsentManager.getInstance().load(context)
    this.allowUpload = PrivacyConsentManager.getInstance().canUpload()
    this.apiKey = config.apiKey
    this.baseURL = config.baseURL
    this.model = config.model
    this.maxTokens = config.maxTokens
    this.temperature = config.temperature
    AppStorage.setOrCreate('llmConfigured', this.manager.isConfigured())
  }

  build() {
    Column() {
      Row() {
        Button('返回').onClick(() => router.back()).margin({ left: 16 })
        Text('LLM 配置').fontSize(20).fontWeight(FontWeight.Bold).layoutWeight(1).textAlign(TextAlign.Center)
        Blank().width(64)
      }
      .width('100%').height(56).backgroundColor('#F1F3F5')
      Scroll() {
        Column({ space: 16 }) {
          this.field('API Key', '输入 API Key', this.apiKey, (value: string) => this.apiKey = value, InputType.Password)
          this.field('Chat Base URL', 'https://api.openai.com/v1', this.baseURL, (value: string) => this.baseURL = value, InputType.Normal)
          this.field('Chat Model', '模型名称', this.model, (value: string) => this.model = value, InputType.Normal)
          Text(`最大 Tokens：${this.maxTokens}`).fontSize(15)
          Slider({ value: this.maxTokens, min: 100, max: 4000, step: 100 }).onChange((value: number) => this.maxTokens = value)
          Text(`Temperature：${this.temperature.toFixed(1)}`).fontSize(15)
          Slider({ value: this.temperature, min: 0, max: 2, step: 0.1 }).onChange((value: number) => this.temperature = value)
          Row({ space: 10 }) {
            Button(this.testing ? '测试中…' : '测试连接').layoutWeight(1).enabled(!this.testing).onClick(() => this.testConnection())
            Button('保存').layoutWeight(1).onClick(() => this.save())
          }.width('100%')
          Button(this.allowUpload ? '已同意上传受限文件片段' : '同意上传受限文件片段')
            .width('100%')
            .fontColor(this.allowUpload ? '#258A57' : '#555555')
            .backgroundColor(this.allowUpload ? '#E5F7EF' : '#F1F3F5')
            .onClick(() => this.toggleUploadConsent())
          Button('清除 API Key').width('100%').fontColor('#D14343').backgroundColor('#FFF0F0').onClick(() => this.clearKey())
          if (this.status.length > 0) Text(this.status).fontSize(13).fontColor(this.statusError ? '#D14343' : '#258A57')
          Column({ space: 8 }) {
            Text('安全说明').fontWeight(FontWeight.Medium)
            Text('API Key 使用系统安全存储保护，页面只显示密码掩码。').fontSize(12).fontColor('#666666')
            Text('本地 Embedding 只在设备上运行，不上传原始文件。').fontSize(12).fontColor('#666666')
          }.width('100%').alignItems(HorizontalAlign.Start).padding(16).backgroundColor('#F8F9FA').borderRadius(8)
        }.width('100%').padding(16)
      }.layoutWeight(1)
    }.width('100%').height('100%').backgroundColor('#FFFFFF')
  }

  @Builder
  private field(label: string, placeholder: string, value: string, onChange: (value: string) => void, type: InputType) {
    Column({ space: 8 }) {
      Text(label).fontSize(15).fontWeight(FontWeight.Medium)
      TextInput({ placeholder: placeholder, text: value }).type(type).width('100%').onChange(onChange)
    }.width('100%').alignItems(HorizontalAlign.Start)
  }

  private updateManager(): void {
    this.manager.updateConfig({ apiKey: this.apiKey, baseURL: this.baseURL, model: this.model, maxTokens: this.maxTokens, temperature: this.temperature })
  }

  private async save(): Promise<void> {
    this.updateManager()
    try {
      const context = getContext(this) as common.UIAbilityContext
      await this.manager.persist(context)
      await PrivacyConsentManager.getInstance().setConsent(context, this.allowUpload)
      LLMService.getInstance().reinitialize()
      AppStorage.setOrCreate('llmConfigured', this.manager.isConfigured())
      this.statusError = false
      this.status = '配置已保存，无需重启即可使用'
    } catch (error) {
      this.statusError = true
      this.status = '保存失败：系统安全存储不可用'
    }
  }

  private async testConnection(): Promise<void> {
    this.updateManager()
    if (!this.manager.isConfigured()) {
      this.statusError = true
      this.status = '请先输入 API Key'
      return
    }
    this.testing = true
    this.statusError = false
    this.status = '正在测试连接…'
    try {
      LLMService.getInstance().reinitialize()
      await LLMService.getInstance().testConnection()
      this.status = '连接成功'
    } catch (error) {
      this.statusError = true
      this.status = '连接失败，请检查地址、模型和网络'
    } finally {
      this.testing = false
    }
  }

  private async toggleUploadConsent(): Promise<void> {
    const context = getContext(this) as common.UIAbilityContext
    try {
      this.allowUpload = !this.allowUpload
      await PrivacyConsentManager.getInstance().setConsent(context, this.allowUpload)
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
