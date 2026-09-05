import preferences from '@ohos.data.preferences'
import { common } from '@kit.AbilityKit'
import batteryInfo from '@ohos.batteryInfo'

export interface OrganizeSchedule { enabled: boolean; charging: boolean; startHour: number; endHour: number }
export function inOrganizeWindow(hour: number, start: number, end: number): boolean {
  if (start === end) return false
  return start < end ? hour >= start && hour < end : hour >= start || hour < end
}
export function deviceCharging(): boolean {
  return batteryInfo.chargingStatus === batteryInfo.BatteryChargeState.ENABLE ||
    batteryInfo.chargingStatus === batteryInfo.BatteryChargeState.FULL
}
export class OrganizeSettings {
  private store: preferences.Preferences
  constructor(context: common.Context) { this.store = preferences.getPreferencesSync(context, { name: 'organize_schedule' }) }
  get(): OrganizeSchedule {
    return { enabled: this.store.getSync('enabled', true) as boolean,
      charging: this.store.getSync('charging', true) as boolean,
      startHour: this.store.getSync('startHour', 2) as number,
      endHour: this.store.getSync('endHour', 4) as number }
  }
  async save(value: OrganizeSchedule): Promise<void> {
    if (!Number.isInteger(value.startHour) || !Number.isInteger(value.endHour) ||
      value.startHour < 0 || value.startHour > 23 || value.endHour < 0 || value.endHour > 23 || value.startHour === value.endHour) {
      throw new Error('请输入 0–23 的整点，开始和结束时间不能相同')
    }
    this.store.putSync('enabled', value.enabled)
    this.store.putSync('charging', value.charging)
    this.store.putSync('startHour', value.startHour)
    this.store.putSync('endHour', value.endHour)
    await this.store.flush()
  }
  allowed(isCharging: boolean = deviceCharging(), hour: number = new Date().getHours()): boolean {
    const settings = this.get()
    return settings.enabled && ((settings.charging && isCharging) || inOrganizeWindow(hour, settings.startHour, settings.endHour))
  }
}
