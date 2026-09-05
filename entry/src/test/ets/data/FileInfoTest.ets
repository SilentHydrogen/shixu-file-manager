// entry/src/test/ets/data/FileInfoTest.ets

import { describe, it, expect } from '@ohos/hypium'
import { FileInfo } from '../../../main/ets/data/model/FileInfo'

export default function fileInfoTest() {
  describe('FileInfo', () => {
    it('should create FileInfo from constructor', 0, () => {
      const fileInfo = new FileInfo()
      fileInfo.uri = 'file://test.pdf'
      fileInfo.name = 'test.pdf'
      fileInfo.type = 'application/pdf'
      fileInfo.size = 1024
      fileInfo.path = '/data/storage/test.pdf'
      fileInfo.createdTime = Date.now()
      fileInfo.modifiedTime = Date.now()

      expect(fileInfo.name).assertEqual('test.pdf')
      expect(fileInfo.isProcessed).assertFalse()
    })

    it('should convert to ValuesBucket correctly', 0, () => {
      const fileInfo = new FileInfo()
      fileInfo.uri = 'file://test.pdf'
      fileInfo.name = 'test.pdf'
      fileInfo.type = 'application/pdf'
      fileInfo.size = 1024
      fileInfo.path = '/data/storage/test.pdf'
      fileInfo.createdTime = 123456789
      fileInfo.modifiedTime = 123456789

      const bucket = fileInfo.toValuesBucket()
      expect(bucket.uri).assertEqual('file://test.pdf')
      expect(bucket.is_processed).assertEqual(0)
      expect(bucket.created_time).assertEqual(123456789)
    })
  })
}
