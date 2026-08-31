import { workScheduler } from '@kit.BackgroundTasksKit'
import { FileProcessingQueue } from './FileProcessingQueue'
import { RagAnalysisService } from './RagAnalysisService'

export class BackgroundAnalysisScheduler {
  private queue: FileProcessingQueue = new FileProcessingQueue()
  private service: RagAnalysisService = new RagAnalysisService()
  private retryCount: Map<number, number> = new Map()
  private running: boolean = false

  enqueue(fileIds: number[]): void {
    for (const fileId of fileIds) this.queue.enqueue(fileId)
  }
  async runBatch(isCharging: boolean, isWifi: boolean, hour: number): Promise<void> {
    if (this.running || !this.allowedWindow(isCharging, isWifi, hour)) return
    this.running = true
    try {
      const batch = this.queue.dequeueBatch(20)
      for (const task of batch) {
        try {
          await this.service.processFile(task.fileId)
          this.retryCount.delete(task.fileId)
        } catch (error) {
          const retries: number = (this.retryCount.get(task.fileId) ?? 0) + 1
          if (retries <= 3) {
            this.retryCount.set(task.fileId, retries)
            this.queue.enqueue(task.fileId, task.priority)
          }
        }
      }
    } finally { this.running = false }
  }
  async schedule(): Promise<void> {
    workScheduler.startWork({
      workId: 1001,
      bundleName: 'com.example.shixufilemanager',
      abilityName: 'EntryAbility',
      networkType: workScheduler.NetworkType.NETWORK_TYPE_WIFI,
      chargerType: workScheduler.ChargingType.CHARGING_PLUGGED_AC,
      repeatCycleTime: 24 * 60 * 60 * 1000,
      isPersisted: true,
      isRepeat: true
    })
  }
  async cancel(): Promise<void> {
    workScheduler.stopWork({ workId: 1001, bundleName: 'com.example.shixufilemanager', abilityName: 'EntryAbility' }, true)
  }
  canRunNow(isCharging: boolean, isWifi: boolean, hour: number): boolean {
    return this.allowedWindow(isCharging, isWifi, hour)
  }
  private allowedWindow(isCharging: boolean, isWifi: boolean, hour: number): boolean {
    return isWifi && (isCharging || (hour >= 2 && hour < 4))
  }
}
