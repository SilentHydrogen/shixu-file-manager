import router from '@ohos.router'
import { common } from '@kit.AbilityKit'
import { LLMService } from '../llm/LLMService'
import { FileAnalysisResult } from '../llm/LLMTypes'
import { PrivacyConsentManager } from '../service/PrivacyConsentManager'
import { ReviewSuggestionService } from '../service/ReviewSuggestionService'

interface OrganizeFile { id: number; name: string; kind: string; contentText: string; tag: string }
interface Suggestion { fileId: number; fileName: string; result: FileAnalysisResult }

@Entry
@Component
struct AIOrganizePage {
  @State files: OrganizeFile[] = []
  @State suggestions: Suggestion[] = []
  @State isLoading: boolean = false
  @State statusMessage: string = ''
  private llmService: LLMService = LLMService.getInstance()
  private reviewService: ReviewSuggestionService = new ReviewSuggestionService()
  @State canUpload: boolean = false

  async aboutToAppear(): Promise<void> {
    await PrivacyConsentManager.getInstance().load(getContext(this) as common.UIAbilityContext)
    this.canUpload = PrivacyConsentManager.getInstance().canUpload()
    const value: string | undefined = AppStorage.get<string>('fileBoxFiles')
    if (value !== undefined) {
      try { this.files = JSON.parse(value) as OrganizeFile[] } catch (error) { this.statusMessage = '文件列表读取失败' }
    }
  }

  build() {
    Column() {
      Row() {
        Button('返回').onClick(() => router.back()).margin({ left: 16 })
        Text('AI 智能整理').fontSize(20).fontWeight(FontWeight.Bold).layoutWeight(1).textAlign(TextAlign.Center)
        Blank().width(64)
      }.width('100%').height(56).backgroundColor('#F1F3F5')
      if (this.files.length === 0) {
        Column() {
          Text('暂无可分析文件').fontSize(18).fontWeight(FontWeight.Medium)
          Text('请先在收纳箱导入文件').fontSize(14).fontColor('#666666').margin({ top: 8 })
        }.layoutWeight(1).justifyContent(FlexAlign.Center)
      } else {
        Scroll() {
          Column({ space: 12 }) {
            Text('分析前会在本地提取内容，结果先进入待确认建议。').fontSize(13).fontColor('#666666').width('100%')
            ForEach(this.files, (file: OrganizeFile) => this.fileRow(file), (file: OrganizeFile) => `${file.id}-${file.name}`)
            if (this.suggestions.length > 0) {
              Text('待确认建议').fontSize(18).fontWeight(FontWeight.Bold).alignSelf(ItemAlign.Start).margin({ top: 8 })
              ForEach(this.suggestions, (item: Suggestion) => this.suggestionRow(item), (item: Suggestion) => `${item.fileId}-${item.result.suggestedCategory}`)
            }
          }.width('100%').padding(16)
        }.layoutWeight(1)
      }
      if (this.statusMessage.length > 0) Text(this.statusMessage).fontSize(13).fontColor('#666666').padding(10)
    }.width('100%').height('100%').backgroundColor('#FFFFFF')
  }

  @Builder
  private fileRow(file: OrganizeFile) {
    Row() {
      Column() {
        Text(file.name).fontSize(15).fontWeight(FontWeight.Medium).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(file.tag.length > 0 ? `当前分类：${file.tag}` : '待分析').fontSize(12).fontColor('#666666').margin({ top: 5 })
      }.layoutWeight(1)
      Button('分析').enabled(!this.isLoading).onClick(() => this.analyze(file))
    }.width('100%').padding(14).backgroundColor('#F8F9FA').borderRadius(14)
  }

  @Builder
  private suggestionRow(item: Suggestion) {
    Column({ space: 6 }) {
      Text(item.fileName).fontSize(15).fontWeight(FontWeight.Medium)
      Text(`建议分类：${item.result.suggestedCategory ?? item.result.category}`).fontSize(14).fontColor('#258A57')
      Text(`置信度：${((item.result.confidence ?? 0) * 100).toFixed(0)}%`).fontSize(12).fontColor('#666666')
      Text(item.result.reason ?? '暂无理由').fontSize(12).fontColor('#666666').maxLines(3).textOverflow({ overflow: TextOverflow.Ellipsis })
    }.width('100%').alignItems(HorizontalAlign.Start).padding(14).backgroundColor('#F0FAF4').borderRadius(14)
  }

  private async analyze(file: OrganizeFile): Promise<void> {
    if (!this.llmService.isConfigured()) { this.statusMessage = '请先在 LLM 配置页完成配置'; return }
    if (!this.canUpload) { this.statusMessage = '请先在配置页同意上传受限文件片段'; return }
    this.isLoading = true
    this.statusMessage = `正在分析「${file.name}」…`
    try {
      const result: FileAnalysisResult = await this.llmService.analyzeFile(file.name, file.kind, file.contentText.substring(0, 8000), ['工作', '项目', '生活', '灵感', '待整理'])
      this.reviewService.add({
        id: `${file.id}-${Date.now()}`,
        fileId: file.id,
        fileName: file.name,
        suggestedCategory: result.suggestedCategory ?? result.category,
        confidence: result.confidence ?? 0,
        reason: result.reason ?? ''
      })
      this.suggestions = this.suggestions.filter((item: Suggestion) => item.fileId !== file.id)
      this.suggestions = [...this.suggestions, { fileId: file.id, fileName: file.name, result: result }]
      this.statusMessage = '分析完成，请确认建议后再修改分类'
    } catch (error) { this.statusMessage = '分析失败，请检查配置、网络或服务响应' }
    finally { this.isLoading = false }
  }
}
