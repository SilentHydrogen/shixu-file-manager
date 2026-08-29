// entry/src/test/ets/data/FileInfoTest.ets

import { describe, it, expect } from '@ohos/hypium'
import { FileInfo } from '../../../main/ets/data/model/FileInfo'

export default function fileInfoTest() {
  describe('FileInfo', () => {
    it('should create FileInfo from constructor', () => {
      const fileInfo = new FileInfo({
        uri: 'file://test.pdf',
        name: 'test.pdf',
        type: 'application/pdf',
        size: 1024,
        path: '/data/storage/test.pdf',
        createdTime: Date.now(),
        modifiedTime: Date.now()
      })

      expect(fileInfo.name).assertEqual('test.pdf')
      expect(fileInfo.isProcessed).assertFalse()
    })

    it('should convert to ValuesBucket correctly', () => {
      const fileInfo = new FileInfo({
        uri: 'file://test.pdf',
        name: 'test.pdf',
        type: 'application/pdf',
        size: 1024,
        path: '/data/storage/test.pdf',
        createdTime: 123456789,
        modifiedTime: 123456789
      })

      const bucket = fileInfo.toValuesBucket()
      expect(bucket.uri).assertEqual('file://test.pdf')
      expect(bucket.is_processed).assertEqual(0)
      expect(bucket.created_time).assertEqual(123456789)
    })
  })
}
