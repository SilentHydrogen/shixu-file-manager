// entry/src/main/ets/data/model/Collection.ets

import { CollectionRule } from './CollectionRule'

export class Collection {
  id?: number
  name: string
  icon?: string
  color?: string
  description?: string
  rules: CollectionRule[] = []
  createdTime: number = Date.now()
  isPreset: boolean = false

  constructor(init?: Partial<Collection>) {
    Object.assign(this, init)
  }

  /**
   * 从数据库行转换为 Collection
   */
  static fromRow(row: any): Collection {
    return new Collection({
      id: row.id,
      name: row.name,
      icon: row.icon,
      color: row.color,
      description: row.description,
      rules: row.rules ? JSON.parse(row.rules) : [],
      createdTime: row.created_time,
      isPreset: row.is_preset === 1
    })
  }

  /**
   * 转换为数据库行对象
   */
  toValuesBucket(): Record<string, any> {
    const values: Record<string, any> = {
      name: this.name,
      rules: JSON.stringify(this.rules),
      created_time: this.createdTime,
      is_preset: this.isPreset ? 1 : 0
    }

    if (this.icon) values.icon = this.icon
    if (this.color) values.color = this.color
    if (this.description) values.description = this.description

    return values
  }
}
