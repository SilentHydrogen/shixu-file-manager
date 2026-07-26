import { Want, wantConstant } from '@kit.AbilityKit';

export function openTypeFromExtension(extension: string): string {
  const normalized: string = extension.toLowerCase().replace('.', '');
  if (['txt', 'md', 'log', 'csv'].includes(normalized)) {
    return 'text/plain';
  }
  if (['json', 'json5'].includes(normalized)) {
    return 'application/json';
  }
  if (['html', 'htm'].includes(normalized)) {
    return 'text/html';
  }
  if (normalized === 'xml') {
    return 'text/xml';
  }
  if (normalized === 'pdf') {
    return 'application/pdf';
  }
  if (normalized === 'doc') {
    return 'application/msword';
  }
  if (normalized === 'docx') {
    return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
  }
  if (normalized === 'ppt') {
    return 'application/vnd.ms-powerpoint';
  }
  if (normalized === 'pptx') {
    return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
  }
  if (normalized === 'xls') {
    return 'application/vnd.ms-excel';
  }
  if (normalized === 'xlsx') {
    return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
  }
  if (['jpg', 'jpeg', 'png', 'heic', 'gif', 'bmp', 'webp', 'svg'].includes(normalized)) {
    return 'image/*';
  }
  if (['mp3', 'm4a', 'wav', 'flac', 'wma'].includes(normalized)) {
    return 'audio/*';
  }
  if (['mp4', 'mov', 'avi', 'mkv'].includes(normalized)) {
    return 'video/*';
  }
  if (['zip', 'rar', '7z'].includes(normalized)) {
    return 'application/zip';
  }
  return '';
}

export function buildFileOpenWant(uri: string, extension: string): Want {
  const type: string = openTypeFromExtension(extension);
  const want: Want = {
    action: 'ohos.want.action.viewData',
    uri: uri,
    flags: wantConstant.Flags.FLAG_AUTH_READ_URI_PERMISSION | wantConstant.Flags.FLAG_AUTH_WRITE_URI_PERMISSION,
    parameters: {
      'ohos.ability.params.showDefaultPicker': true
    }
  };
  if (type.length > 0) {
    want.type = type;
  }
  return want;
}

export function buildFileSendWant(uri: string, extension: string): Want {
  const type: string = openTypeFromExtension(extension);
  const want: Want = {
    action: 'ohos.want.action.sendData',
    uri: uri,
    flags: wantConstant.Flags.FLAG_AUTH_READ_URI_PERMISSION | wantConstant.Flags.FLAG_AUTH_WRITE_URI_PERMISSION,
    parameters: {
      'ability.params.stream': [uri],
      'ohos.ability.params.showDefaultPicker': true
    }
  };
  if (type.length > 0) {
    want.type = type;
  }
  return want;
}
