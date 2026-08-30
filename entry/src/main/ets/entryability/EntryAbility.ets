import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { DatabaseManager } from '../data/database/DatabaseManager';

const DOMAIN = 0x0000;

interface CardRouteParams {
  message: string;
}

export default class EntryAbility extends UIAbility {
  async onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): Promise<void> {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onCreate');

    // 初始化数据库
    try {
      await DatabaseManager.getInstance().init(this.context);
      hilog.info(DOMAIN, 'testTag', '%{public}s', '[EntryAbility] Database initialized successfully');
    } catch (err) {
      hilog.error(DOMAIN, 'testTag', '[EntryAbility] Database initialization failed: %{public}s', JSON.stringify(err));
    }

    AppStorage.setOrCreate('pendingSharedUris', '');
    AppStorage.setOrCreate('pendingCardRoute', '');
    this.receiveSharedFiles(want);
    this.routeFromCard(want);
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

  private routeFromCard(want: Want): void {
    if (want.parameters === undefined) {
      return;
    }
    const paramsValue: Object | undefined = want.parameters['params'];
    if (typeof paramsValue === 'string') {
      try {
        const params: CardRouteParams = JSON.parse(paramsValue) as CardRouteParams;
        const message: string = params.message;
        if (message === 'recent-files' || message === 'quick-categories') {
          AppStorage.setOrCreate('pendingCardRoute', message);
        }
      } catch (error) {
      }
    }
  }

  onNewWant(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    this.receiveSharedFiles(want);
    this.routeFromCard(want);
  }

  onDestroy(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onDestroy');
    // 关闭数据库
    DatabaseManager.getInstance().close().catch((err: Error) => {
      hilog.error(DOMAIN, 'testTag', 'Database close failed: %{public}s', JSON.stringify(err))
    })
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