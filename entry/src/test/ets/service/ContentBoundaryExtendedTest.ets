import { describe, it, expect } from '@ohos/hypium'
import { clampUploadContent, clampUploadContexts } from '../../../main/ets/service/ContentBoundary'

export default function contentBoundaryExtendedTest() {
  describe('ContentBoundaryExtended', () => {
    it('limits each upload to configured fraction', 0, () => {
      expect(clampUploadContent('1234567890')).assertEqual('12')
    })
    it('limits aggregate contexts', 0, () => {
      expect(clampUploadContexts(['abcdefghij', 'klmnopqrst'], 3).join('')).assertEqual('abk')
    })
  })
}
