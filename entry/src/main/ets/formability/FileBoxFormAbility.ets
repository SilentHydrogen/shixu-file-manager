import { formBindingData, FormExtensionAbility, formInfo, formProvider } from '@kit.FormKit';
import { Want } from '@kit.AbilityKit';
import preferences from '@ohos.data.preferences';

interface StoredFile {
  id: number;
  name: string;
  kind: string;
  updated: string;
  tag: string;
  color: string;
  icon: string;
  uri: string;
  importedAt: number;
  lastAccessedAt?: number;
}

interface StoredCategory {
  name: string;
  color: string;
  icon: string;
}

interface WidgetFile {
  id: number;
  name: string;
  kind: string;
  updated: string;
  tag: string;
  color: string;
  icon: string;
}

interface WidgetCategory {
  name: string;
  color: string;
  icon: string;
  count: number;
}

export default class FileBoxFormAbility extends FormExtensionAbility {
  private readonly preferenceName: string = 'file_box_data';
  private readonly formIdsKey: string = 'widgetFormIds';

  private readArray<T>(value: preferences.ValueType): T[] {
    if (typeof value !== 'string' || value.length === 0) {
      return [];
    }
    try {
      return JSON.parse(value) as T[];
    } catch (error) {
      return [];
    }
  }

  private createWidgetData(): formBindingData.FormBindingData {
    let files: StoredFile[] = [];
    let categories: StoredCategory[] = [];
    try {
      const store = preferences.getPreferencesSync(this.context, { name: this.preferenceName });
      files = this.readArray<StoredFile>(store.getSync('files', '[]'));
      categories = this.readArray<StoredCategory>(store.getSync('categories', '[]'));
    } catch (error) {
    }
    const sortedFiles: StoredFile[] = [...files].sort((left: StoredFile, right: StoredFile) => {
      const leftTime: number = Math.max(left.lastAccessedAt === undefined ? 0 : left.lastAccessedAt, left.importedAt);
      const rightTime: number = Math.max(right.lastAccessedAt === undefined ? 0 : right.lastAccessedAt, right.importedAt);
      return rightTime - leftTime;
    });
    const recentFiles: WidgetFile[] = sortedFiles.slice(0, 8).map((file: StoredFile) => {
      const item: WidgetFile = {
        id: file.id,
        name: file.name,
        kind: file.kind,
        updated: file.updated,
        tag: file.tag,
        color: file.color,
        icon: file.icon
      };
      return item;
    });
    const categoryItems: WidgetCategory[] = categories.slice(0, 6).map((category: StoredCategory) => {
      const item: WidgetCategory = {
        name: category.name,
        color: category.color,
        icon: category.icon,
        count: files.filter((file: StoredFile) => file.tag === category.name).length
      };
      return item;
    });
    const now: Date = new Date();
    const minutes: string = now.getMinutes() < 10 ? `0${now.getMinutes()}` : `${now.getMinutes()}`;
    return formBindingData.createFormBindingData({
      recentFilesJson: JSON.stringify(recentFiles),
      categoriesJson: JSON.stringify(categoryItems),
      totalCount: files.length,
      updatedTime: `${now.getHours()}:${minutes}`
    });
  }

  private rememberForm(formId: string): void {
    if (formId.length === 0) {
      return;
    }
    try {
      const store = preferences.getPreferencesSync(this.context, { name: this.preferenceName });
      const formIds: string[] = this.readArray<string>(store.getSync(this.formIdsKey, '[]'));
      if (!formIds.includes(formId)) {
        store.putSync(this.formIdsKey, JSON.stringify([...formIds, formId]));
        store.flush().catch(() => {});
      }
    } catch (error) {
    }
  }

  onAddForm(want: Want) {
    if (want.parameters !== undefined) {
      const formIdValue: Object | undefined = want.parameters[formInfo.FormParam.IDENTITY_KEY];
      if (typeof formIdValue === 'string') {
        this.rememberForm(formIdValue);
      }
    }
    return this.createWidgetData();
  }

  onUpdateForm(formId: string): void {
    this.rememberForm(formId);
    formProvider.updateForm(formId, this.createWidgetData()).catch(() => {});
  }

  onCastToNormalForm(formId: string): void {
  }

  onFormEvent(formId: string, message: string): void {
  }

  onRemoveForm(formId: string): void {
    try {
      const store = preferences.getPreferencesSync(this.context, { name: this.preferenceName });
      const formIds: string[] = this.readArray<string>(store.getSync(this.formIdsKey, '[]'));
      store.putSync(this.formIdsKey, JSON.stringify(formIds.filter((id: string) => id !== formId)));
      store.flush().catch(() => {});
    } catch (error) {
    }
  }

  onAcquireFormState(want: Want) {
    return formInfo.FormState.READY;
  }
}
