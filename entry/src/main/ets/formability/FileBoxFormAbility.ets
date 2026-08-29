import { formBindingData, FormExtensionAbility, formInfo } from '@kit.FormKit';
import { Want } from '@kit.AbilityKit';
import preferences from '@ohos.data.preferences';
import { WidgetCategory, WidgetData, WidgetFile } from '../model/WidgetData';

interface PersistedFile {
  name: string;
  tag: string;
  color: string;
  icon: string;
}

interface PersistedCategory {
  name: string;
  color: string;
}

export default class FileBoxFormAbility extends FormExtensionAbility {
  onAddForm(want: Want): formBindingData.FormBindingData {
    return formBindingData.createFormBindingData(this.buildWidgetData());
  }

  onUpdateForm(formId: string): formBindingData.FormBindingData {
    return formBindingData.createFormBindingData(this.buildWidgetData());
  }

  onCastToNormalForm(formId: string): void {
  }

  onFormEvent(formId: string, message: string): void {
  }

  onRemoveForm(formId: string): void {
  }

  onAcquireFormState(want: Want): formInfo.FormState {
    return formInfo.FormState.READY;
  }

  private buildWidgetData(): WidgetData {
    const data: WidgetData = {
      totalCount: 0,
      pendingCount: 0,
      categoryList: [],
      recentList: []
    };
    try {
      const store = preferences.getPreferencesSync(this.context, { name: 'file_box_data' });
      const filesValue = store.getSync('files', '[]');
      const categoriesValue = store.getSync('categories', '[]');
      const files: PersistedFile[] = typeof filesValue === 'string'
        ? JSON.parse(filesValue) as PersistedFile[]
        : [];
      const categories: PersistedCategory[] = typeof categoriesValue === 'string'
        ? JSON.parse(categoriesValue) as PersistedCategory[]
        : [];

      data.totalCount = files.length;
      data.pendingCount = files.filter((file: PersistedFile) => file.tag === '待整理').length;

      const categoryList: WidgetCategory[] = categories
        .filter((category: PersistedCategory) => category.name !== '待整理')
        .slice(0, 3)
        .map((category: PersistedCategory): WidgetCategory => {
          const count: number = files.filter((file: PersistedFile) => file.tag === category.name).length;
          const item: WidgetCategory = { name: category.name, count: count, color: category.color };
          return item;
        });
      data.categoryList = categoryList;

      const recentList: WidgetFile[] = files
        .filter((file: PersistedFile) => file.tag !== '待整理')
        .slice(0, 2)
        .map((file: PersistedFile): WidgetFile => {
          const item: WidgetFile = { name: file.name, tag: file.tag, color: file.color, icon: file.icon };
          return item;
        });
      data.recentList = recentList;
    } catch (error) {
      // 读取失败时保持空数据，卡片仍可正常渲染
    }
    return data;
  }
}