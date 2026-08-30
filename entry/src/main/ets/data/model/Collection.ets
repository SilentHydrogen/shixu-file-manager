// entry/src/main/ets/data/model/Collection.ets

import relationalStore from '@ohos.data.relationalStore'
import { CollectionRule } from './CollectionRule'

export class Collection {
  id?: number
  name: string = ''
  icon?: string
  color?: string
  description?: string
  rules: CollectionRule[] = []
  createdTime: number = Date.now()
  isPreset: boolean = false

  /**
   * 从数据库行转换为 Collection
   */
  static fromRow(row: Record<string, Object>): Collection {
    const collection = new Collection()
    collection.id = row.id as number
    collection.name = row.name as string
    collection.icon = row.icon as string
    collection.color = row.color as string
    collection.description = row.description as string
    collection.rules = row.rules ? JSON.parse(row.rules as string) as CollectionRule[] : []
    collection.createdTime = row.created_time as number
    collection.isPreset = (row.is_preset as number) === 1
    return collection
  }

  /**
   * 转换为数据库行对象
   */
  toValuesBucket(): relationalStore.ValuesBucket {
    const values: relationalStore.ValuesBucket = {
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
