import { common } from '@kit.AbilityKit'
import { FileItem } from '../data/model/FileBoxTypes'
import { ClassificationMetrics, FileOrganizeService } from '../service/FileOrganizeService'
import { ReviewSuggestion } from '../service/ReviewSuggestionService'
import { OrganizeSettings } from '../service/OrganizeSettings'
import { BackgroundAnalysisScheduler } from '../service/BackgroundAnalysisScheduler'
import { describeLLMError } from '../llm/OpenAIClient'

@Entry
@Component
struct AIOrganizePage {
  @State files: FileItem[] = []
  @State suggestions: ReviewSuggestion[] = []
  @StorageLink('organizeRunning') @Watch('onRunStateChanged') organizeRunning: boolean = false
  @State isLoading: boolean = true
  @State statusMessage: string = ''
  @State usesLLM: boolean = false
  @State metrics: ClassificationMetrics = {
    attempted: 0, recognized: 0, autoClassified: 0, manualConfirmed: 0,
    pendingReview: 0, failed: 0, recognitionRate: 0, autoRate: 0, lastUpdated: 0
  }
  @State backgroundEnabled: boolean = true
  @State charging: boolean = true
  @State startHour: string = '2'
  @State endHour: string = '4'
  @State activeFileId: number = -1
  private service: FileOrganizeService = FileOrganizeService.getInstance()

  onPageShow(): void { this.refresh() }
  private async refresh(): Promise<void> {
    this.isLoading = true
    try {
      const context = getContext(this) as common.UIAbilityContext
      await this.service.initialize(context)
      this.loadResults()
      const settings = new OrganizeSettings(context).get()
      this.backgroundEnabled = settings.enabled
      this.charging = settings.charging
      this.startHour = `${settings.startHour}`
      this.endHour = `${settings.endHour}`
    } catch (error) { this.statusMessage = describeLLMError(error) }
    finally { this.isLoading = false }
  }
  private onRunStateChanged(): void {
    if (!this.organizeRunning && !this.isLoading) {
      try { this.loadResults() } catch (error) { this.statusMessage = '请返回后刷新整理结果' }
    }
  }
  private loadResults(): void {
    this.files = this.service.files()
    this.suggestions = this.service.pendingReviews()
    this.usesLLM = this.service.usesLLM()
    this.metrics = this.service.metrics()
  }
  private async organize(fileId?: number): Promise<void> {
    if (this.isLoading) return
    this.isLoading = true
    this.activeFileId = fileId ?? -1
    this.statusMessage = this.usesLLM ? '正在检索相关文件并使用 LLM 分类…' : '正在使用本地 Embedding 扩展关键词分类…'
    try {
      const result = await this.service.organize(fileId)
      this.loadResults()
      this.statusMessage = `已归类 ${result.applied} · 待确认 ${result.review} · 保留 ${result.skipped} · 失败 ${result.failed}` +
        (result.remaining > 0 ? ` · 还有 ${result.remaining} 个，继续整理可处理下一批` : '')
    } catch (error) { this.statusMessage = describeLLMError(error) }
    finally { this.isLoading = false; this.activeFileId = -1 }
  }
  private async saveSchedule(): Promise<void> {
    try {
      const context = getContext(this) as common.UIAbilityContext
      await new OrganizeSettings(context).save({ enabled: this.backgroundEnabled, charging: this.charging,
        startHour: Number(this.startHour), endHour: Number(this.endHour) })
      if (!this.backgroundEnabled) this.service.cancelBackground()
      await new BackgroundAnalysisScheduler(context).schedule()
      this.statusMessage = '后台整理设置已保存'
    } catch (error) { this.statusMessage = describeLLMError(error) }
  }
  private async review(item: ReviewSuggestion, accept: boolean): Promise<void> {
    if (this.isLoading) return
    this.isLoading = true
    try {
      if (accept) await this.service.acceptSuggestion(item.id)
      else await this.service.rejectSuggestion(item.id)
      this.loadResults()
      this.statusMessage = accept ? '已确认分类' : '已保留原分类'
    } catch (error) { this.statusMessage = describeLLMError(error) }
    finally { this.isLoading = false }
  }

  build() {
    Column() {
      Row() {
        Button('返回').onClick(() => this.getUIContext().getRouter().back())
        Text($r('app.string.ai_classify_title')).fontSize(20).fontWeight(FontWeight.Bold).layoutWeight(1).textAlign(TextAlign.Center)
        Button('模型设置').onClick(() => this.getUIContext().getRouter().pushUrl({ url: 'pages/LLMConfigPage' }))
      }.width('100%').height(56).padding({ left: 16, right: 16 })
      Scroll() {
        Column({ space: 14 }) {
          Column({ space: 8 }) {
            Text(this.usesLLM ? 'LLM + RAG 分类' : '本地 Embedding 分类').fontSize(23).fontWeight(FontWeight.Bold)
            Text($r('app.string.ai_classify_hint')).fontSize(13).fontColor($r('app.color.text_body'))
            Text(this.usesLLM ? '结合相关文件与现有规则，使用已配置模型分析' : '无需配置提供商；文件内容在手机上处理')
              .fontSize(13).fontColor($r('app.color.accent_blue')).id('organizeMode')
            Text(`${this.files.length} 个文件 · ${this.suggestions.length} 条待确认`).fontSize(13)
            Text(`识别率 ${(this.metrics.recognitionRate * 100).toFixed(0)}% · 自动归类率 ${(this.metrics.autoRate * 100).toFixed(0)}% · 已分析 ${this.metrics.attempted} 个`)
              .fontSize(13).fontColor($r('app.color.accent_blue')).id('recognitionRate')
            Button(this.isLoading ? '处理中…' : '立即整理待分类文件').width('100%').enabled(!this.isLoading)
              .id('organizeNow').onClick(() => this.organize())
            if (this.organizeRunning) {
              if (!this.isLoading) Text('后台整理正在运行；点击立即整理可优先接管').fontSize(12).fontColor($r('app.color.text_caption'))
              Button('停止整理').onClick(() => this.service.cancel())
            }
          }.width('100%').alignItems(HorizontalAlign.Start).padding(16).backgroundColor($r('app.color.card_bg')).borderRadius(16)
          Column({ space: 10 }) {
            Row() {
              Text($r('app.string.ai_background_title')).fontSize(17).fontWeight(FontWeight.Medium).layoutWeight(1)
              Toggle({ type: ToggleType.Switch, isOn: this.backgroundEnabled }).onChange((value: boolean) => { this.backgroundEnabled = value })
            }.width('100%')
            Row() {
              Text($r('app.string.ai_charging_trigger')).fontSize(14).layoutWeight(1)
              Toggle({ type: ToggleType.Switch, isOn: this.charging }).onChange((value: boolean) => { this.charging = value })
            }.width('100%')
            Row({ space: 8 }) {
              Text('或每日').fontSize(14)
              TextInput({ text: this.startHour, placeholder: '2' }).type(InputType.Number).width(64).maxLength(2)
                .id('organizeStartHour').onChange((value: string) => { this.startHour = value })
              Text('时至').fontSize(14)
              TextInput({ text: this.endHour, placeholder: '4' }).type(InputType.Number).width(64).maxLength(2)
                .id('organizeEndHour').onChange((value: string) => { this.endHour = value })
              Text('时').fontSize(14)
            }
            Text($r('app.string.ai_schedule_hint')).fontSize(12).fontColor($r('app.color.text_caption'))
            Button('保存后台设置').enabled(!this.isLoading).id('organizeSaveSchedule').onClick(() => this.saveSchedule())
          }.width('100%').alignItems(HorizontalAlign.Start).padding(16).backgroundColor($r('app.color.card_bg')).borderRadius(16)
          if (this.suggestions.length > 0) {
            Text('需要你确认').fontSize(18).fontWeight(FontWeight.Bold).alignSelf(ItemAlign.Start)
            ForEach(this.suggestions, (item: ReviewSuggestion) => this.suggestionRow(item), (item: ReviewSuggestion) => item.id)
          }
          Text('收纳箱文件').fontSize(18).fontWeight(FontWeight.Bold).alignSelf(ItemAlign.Start)
          if (this.files.length === 0) Text('请先在收纳箱导入文件').fontSize(14).fontColor($r('app.color.text_caption'))
          ForEach(this.files, (file: FileItem) => this.fileRow(file), (file: FileItem) => `${file.id}-${file.tag}`)
        }.width('100%').padding(20)
      }.layoutWeight(1)
      if (this.statusMessage.length > 0) Text(this.statusMessage).fontSize(13).fontColor($r('app.color.text_body')).padding(12).id('organizeStatus')
    }.width('100%').height('100%').backgroundColor($r('app.color.page_bg'))
  }
  @Builder
  private fileRow(file: FileItem) {
    Row({ space: 10 }) {
      Column({ space: 5 }) {
        Text(file.name).fontSize(15).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(`${file.tag}${file.manualTag ? ' · 人工确认' : ''}`).fontSize(12).fontColor($r('app.color.text_caption'))
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
      Button(this.activeFileId === file.id ? '处理中' : '分析').enabled(!this.isLoading && !file.manualTag).onClick(() => this.organize(file.id))
    }.width('100%').padding(14).backgroundColor($r('app.color.card_bg')).borderRadius(14)
  }
  @Builder
  private suggestionRow(item: ReviewSuggestion) {
    Column({ space: 8 }) {
      Text(item.fileName).fontSize(15).fontWeight(FontWeight.Medium).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
      Text(item.suggestedCategory === '待整理' ? '暂无明确分类，请在收纳箱手动选择' : `建议归入「${item.suggestedCategory}」`).fontSize(14)
      Text(item.reason).fontSize(12).fontColor($r('app.color.text_body')).maxLines(4)
      Row({ space: 10 }) {
        Button('保留原分类').enabled(!this.isLoading).onClick(() => this.review(item, false))
        Button('确认分类').enabled(!this.isLoading && item.suggestedCategory !== '待整理').onClick(() => this.review(item, true))
      }.width('100%').justifyContent(FlexAlign.End)
    }.width('100%').alignItems(HorizontalAlign.Start).padding(14).backgroundColor($r('app.color.card_bg')).borderRadius(14)
  }
}
