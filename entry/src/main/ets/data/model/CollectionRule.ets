// entry/src/main/ets/data/model/CollectionRule.ets

export enum ConditionType {
  FILE_NAME = 'file_name',
  FILE_TYPE = 'file_type',
  FILE_SIZE = 'file_size',
  KEYWORDS = 'keywords',
  CONTENT_CONTAINS = 'content_contains',
  DATE_RANGE = 'date_range',
  SOURCE_PATH = 'source_path'
}

export enum OperatorType {
  EQUALS = 'equals',
  CONTAINS = 'contains',
  STARTS_WITH = 'starts_with',
  ENDS_WITH = 'ends_with',
  GREATER_THAN = 'greater_than',
  LESS_THAN = 'less_than',
  IN = 'in',
  MATCHES = 'matches'
}

export interface RuleCondition {
  type: ConditionType
  operator: OperatorType
  value: string | number | string[]
}

export class CollectionRule {
  id: number = 0
  collectionId: number = 0
  priority: number = 0
  conditions: RuleCondition[] = []
  enabled: boolean = true
  createdTime: number = Date.now()

  constructor(init?: CollectionRule) {
    if (init) {
      this.id = init.id ?? 0
      this.collectionId = init.collectionId ?? 0
      this.priority = init.priority ?? 0
      this.conditions = init.conditions ?? []
      this.enabled = init.enabled ?? true
      this.createdTime = init.createdTime ?? Date.now()
    }
  }
}
