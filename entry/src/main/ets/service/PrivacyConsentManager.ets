import preferences from '@ohos.data.preferences'
import { common } from '@kit.AbilityKit'

const STORE_NAME: string = 'privacy_settings'
const UPLOAD_CONSENT: string = 'llm_upload_consent'

export class PrivacyConsentManager {
  private static instance: PrivacyConsentManager
  private consent: boolean = false
  private constructor() {}
  static getInstance(): PrivacyConsentManager {
    if (PrivacyConsentManager.instance === undefined) PrivacyConsentManager.instance = new PrivacyConsentManager()
    return PrivacyConsentManager.instance
  }
  async load(context: common.UIAbilityContext): Promise<void> {
    const store = preferences.getPreferencesSync(context, { name: STORE_NAME })
    this.consent = store.getSync(UPLOAD_CONSENT, false) as boolean
  }
  async setConsent(context: common.UIAbilityContext, allowed: boolean): Promise<void> {
    this.consent = allowed
    const store = preferences.getPreferencesSync(context, { name: STORE_NAME })
    store.putSync(UPLOAD_CONSENT, allowed)
    await store.flush()
  }
  canUpload(): boolean { return this.consent }
}
