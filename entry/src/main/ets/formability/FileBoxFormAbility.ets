import { formBindingData, FormExtensionAbility, formInfo } from '@kit.FormKit';
import { Want } from '@kit.AbilityKit';

export default class FileBoxFormAbility extends FormExtensionAbility {
  onAddForm(want: Want) {
    return formBindingData.createFormBindingData('');
  }

  onUpdateForm(formId: string) {
    return formBindingData.createFormBindingData('');
  }

  onCastToNormalForm(formId: string): void {
  }

  onFormEvent(formId: string, message: string): void {
  }

  onRemoveForm(formId: string): void {
  }

  onAcquireFormState(want: Want) {
    return formInfo.FormState.READY;
  }
}
