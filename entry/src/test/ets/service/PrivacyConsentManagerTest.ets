import { describe, it, expect } from '@ohos/hypium'
import { PrivacyConsentManager } from '../../../main/ets/service/PrivacyConsentManager'

export default function privacyConsentManagerTest() {
  describe('PrivacyConsentManager', () => {
    it('defaults to deny', 0, () => {
      expect(PrivacyConsentManager.getInstance().canUpload()).assertFalse()
    })
  })
}
