import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';

const DOMAIN = 0x0000;

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onCreate');
    AppStorage.setOrCreate('pendingSharedUris', '');
    AppStorage.setOrCreate('pendingWidgetAction', '');
    this.receiveSharedFiles(want);
    this.receiveWidgetAction(want);
  }

  private receiveWidgetAction(want: Want): void {
    if (want.parameters === undefined) {
      return;
    }
    const message: Object | undefined = want.parameters['message'];
    if (typeof message === 'string' && message.length > 0) {
      AppStorage.setOrCreate('pendingWidgetAction', message);
    }
  }

  private receiveSharedFiles(want: Want): void {
    const uris: string[] = [];
    if (want.uri !== undefined && want.uri.length > 0) {
      uris.push(want.uri);
    }
    if (want.parameters !== undefined) {
      const streamValue: Object | undefined = want.parameters['ability.params.stream'];
      if (typeof streamValue === 'string') {
        if (!uris.includes(streamValue)) {
          uris.push(streamValue);
        }
      } else if (Array.isArray(streamValue)) {
        const streamUris: Array<string> = streamValue as Array<string>;
        streamUris.forEach((uri: string) => {
          if (uri.length > 0 && !uris.includes(uri)) {
            uris.push(uri);
          }
        });
      }
    }
    if (uris.length > 0) {
      AppStorage.setOrCreate('pendingSharedUris', JSON.stringify(uris));
    }
  }

  onNewWant(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    this.receiveSharedFiles(want);
    this.receiveWidgetAction(want);
  }

  onDestroy(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    // Main window is created, set main page for this ability
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageCreate');

    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, 'testTag', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, 'testTag', 'Succeeded in loading the content.');
    });
  }

  onWindowStageDestroy(): void {
    // Main window is destroyed, release UI related resources
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    // Ability has brought to foreground
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onForeground');
  }

  onBackground(): void {
    // Ability has back to background
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onBackground');
  }
}
