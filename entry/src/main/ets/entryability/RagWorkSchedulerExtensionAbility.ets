import WorkSchedulerExtensionAbility from '@ohos.WorkSchedulerExtensionAbility'
import { workScheduler } from '@kit.BackgroundTasksKit'
import { BackgroundAnalysisScheduler } from '../service/BackgroundAnalysisScheduler'
import { FileOrganizeService } from '../service/FileOrganizeService'
import { hilog } from '@kit.PerformanceAnalysisKit'

export default class RagWorkSchedulerExtensionAbility extends WorkSchedulerExtensionAbility {
  onWorkStart(work: workScheduler.WorkInfo): void {
    hilog.info(0, 'RagWorkScheduler', 'Classification work started: %{public}d', work.workId)
    new BackgroundAnalysisScheduler(this.context).runBatch().then(() => {
      hilog.info(0, 'RagWorkScheduler', 'Classification work completed: %{public}d', work.workId)
    }).catch(() => hilog.warn(0, 'RagWorkScheduler', 'Classification work failed; pending state retained'))
  }
  onWorkStop(work: workScheduler.WorkInfo): void {
    FileOrganizeService.getInstance().cancelBackground()
    hilog.info(0, 'RagWorkScheduler', 'Classification work stopped: %{public}d', work.workId)
  }
}
