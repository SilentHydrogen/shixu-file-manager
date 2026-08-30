/**
 * 服务卡片（FormExtensionAbility）与卡片 UI 之间的数据契约。
 * formBindingData 的键名与卡片 @LocalStorageProp 的 key 保持一致。
 */

export interface WidgetCategory {
  name: string;
  count: number;
  color: string;
}

export interface WidgetFile {
  name: string;
  tag: string;
  color: string;
  icon: string;
}

export interface WidgetData {
  totalCount: number;
  pendingCount: number;
  categoryList: WidgetCategory[];
  recentList: WidgetFile[];
}