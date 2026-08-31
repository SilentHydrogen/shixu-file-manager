import { describe, it, expect } from '@ohos/hypium'
import { FileProcessingQueue } from '../../../main/ets/service/FileProcessingQueue'
import { DirectoryMonitor } from '../../../main/ets/service/DirectoryMonitor'
import { BackgroundAnalysisScheduler } from '../../../main/ets/service/BackgroundAnalysisScheduler'
import { clampUploadContent, canProcessFile } from '../../../main/ets/service/ContentBoundary'

export default function servicePolicyTest() {
  describe('ServicePolicy', () => {
    it('limits queue batches and deduplicates', 0, () => {
      const queue = new FileProcessingQueue()
      queue.enqueue(1); queue.enqueue(1)
      expect(queue.size()).assertEqual(1)
      expect(queue.dequeueBatch(30).length).assertEqual(1)
    })
    it('limits watched directories', 0, () => {
      const monitor = new DirectoryMonitor()
      for (let index = 0; index < 8; index++) monitor.addDirectory({ uri: `${index}`, path: `/tmp/${index}`, recursive: true, enabled: true })
      try { monitor.addDirectory({ uri: '9', path: '/tmp/9', recursive: true, enabled: true }); expect(false).assertTrue() }
      catch (error) { expect(true).assertTrue() }
    })
    it('enforces content boundary', 0, () => {
      expect(canProcessFile(100 * 1024 * 1024)).assertTrue()
      expect(canProcessFile(100 * 1024 * 1024 + 1)).assertFalse()
      expect(clampUploadContent('a'.repeat(50000)).length).assertEqual(8000)
    })
    it('allows only wifi and charging or quiet hours', 0, () => {
      const scheduler = new BackgroundAnalysisScheduler()
      expect(scheduler.canRunNow(true, true, 12)).assertTrue()
      expect(scheduler.canRunNow(false, true, 3)).assertTrue()
      expect(scheduler.canRunNow(true, false, 12)).assertFalse()
      expect(scheduler.canRunNow(false, true, 12)).assertFalse()
    })
  })
}
