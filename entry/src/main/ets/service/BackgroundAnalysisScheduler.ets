import { workScheduler } from '@kit.BackgroundTasksKit'
import { common } from '@kit.AbilityKit'
import { FileOrganizeService } from './FileOrganizeService'
import { FileClassificationStore } from './FileClassificationStore'
import { OrganizeSettings } from './OrganizeSettings'

/** Separate charging and periodic works express OR; eligibility is checked again at execution. */
export class BackgroundAnalysisScheduler {
  private static readonly ABILITY_NAME: string = 'RagWorkSchedulerExtensionAbility'
  private context: common.Context
  private settings: OrganizeSettings
  constructor(context: common.Context) { this.context = context; this.settings = new OrganizeSettings(context) }

  async runBatch(): Promise<void> {
    const allowed = (): boolean => this.settings.allowed() && new FileClassificationStore(this.context).autoEnabled()
    const service = FileOrganizeService.getInstance()
    if (!allowed() || service.isRunning()) return
    await service.initialize(this.context)
    if (!allowed() || service.isRunning()) return
    await service.organize(undefined, allowed, 90000)
  }
  async schedule(): Promise<void> {
    await this.cancel()
    const settings = this.settings.get()
    if (!settings.enabled) return
    if (settings.charging) {
      workScheduler.startWork({ workId: 1001, bundleName: 'com.example.myapplication',
        abilityName: BackgroundAnalysisScheduler.ABILITY_NAME,
        isCharging: true, chargerType: workScheduler.ChargingType.CHARGING_PLUGGED_ANY,
        repeatCycleTime: 20 * 60 * 1000, isPersisted: true, isRepeat: true })
    }
    // WorkScheduler is deferred, not an exact alarm. Each wake-up rechecks the configured local-time window.
    workScheduler.startWork({ workId: 1002, bundleName: 'com.example.myapplication',
      abilityName: BackgroundAnalysisScheduler.ABILITY_NAME,
      repeatCycleTime: 20 * 60 * 1000, isPersisted: true, isRepeat: true })
  }
  async cancel(): Promise<void> {
    const works = await workScheduler.obtainAllWorks()
    for (const work of works) if (work.workId === 1001 || work.workId === 1002) workScheduler.stopWork(work, true)
  }
}
