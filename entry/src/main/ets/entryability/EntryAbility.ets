import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { DatabaseManager } from '../data/database/DatabaseManager';
import { LLMConfigManager } from '../llm/LLMConfig';
import { LLMService } from '../llm/LLMService';
import { PrivacyConsentManager } from '../service/PrivacyConsentManager';
import { RagAnalysisService } from '../service/RagAnalysisService';
import { BackgroundAnalysisScheduler } from '../service/BackgroundAnalysisScheduler';
import { commonEventManager } from '@kit.BasicServicesKit';
import { DirectoryMonitor } from '../service/DirectoryMonitor';

const DOMAIN = 0x0000;

interface CardRouteParams {
  message: string;
}

export default class EntryAbility extends UIAbility {
  private scheduler: BackgroundAnalysisScheduler | null = null;
  private chargeSubscriber: commonEventManager.CommonEventSubscriber | null = null;
  private scheduleTimer: number = -1;
  private monitorDebounceTimer: number = -1;
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
    AppStorage.setOrCreate('llmConfigured', false);
    await PrivacyConsentManager.getInstance().load(this.context).catch((error: Error) => {
      hilog.warn(DOMAIN, 'testTag', 'Privacy settings load failed: %{public}s', JSON.stringify(error));
    });
    await LLMConfigManager.getInstance().load(this.context).then(() => {
      LLMService.getInstance().reinitialize();
      AppStorage.setOrCreate('llmConfigured', LLMConfigManager.getInstance().isConfigured());
    }).catch((error: Error) => {
      hilog.warn(DOMAIN, 'testTag', 'LLM config load failed: %{public}s', JSON.stringify(error));
    });
    try {
      const rag = RagAnalysisService.getInstance();
      await rag.initialize(this.context);
      this.scheduler = new BackgroundAnalysisScheduler(this.context);
      this.scheduler.runBatch().catch(() => {});
      this.scheduleTimer = setInterval(() => this.enqueueUnprocessedFiles(), 60000);
      this.chargeSubscriber = await commonEventManager.createSubscriber({ events: [
        commonEventManager.Support.COMMON_EVENT_CHARGING,
        commonEventManager.Support.COMMON_EVENT_DISCHARGING
      ] });
      commonEventManager.subscribe(this.chargeSubscriber, () => this.enqueueUnprocessedFiles());
      await this.scheduler.schedule().catch((error: Error) => {
        hilog.warn(DOMAIN, 'testTag', 'RAG background scheduling failed: %{public}s', JSON.stringify(error));
      });
      const filesDir: string = this.context.filesDir;
      DirectoryMonitor.getInstance().startWatching({ uri: filesDir, path: filesDir, recursive: true, enabled: true }, () => {
        if (this.monitorDebounceTimer !== -1) clearTimeout(this.monitorDebounceTimer);
        this.monitorDebounceTimer = setTimeout(() => {
          this.monitorDebounceTimer = -1;
          this.enqueueUnprocessedFiles();
        }, 500);
      });
    } catch (error) {
      hilog.warn(DOMAIN, 'testTag', 'RAG initialization failed: %{public}s', JSON.stringify(error));
    }

    this.receiveSharedFiles(want);
    this.routeFromCard(want);
  }

  private enqueueUnprocessedFiles(): void {
    if (this.scheduler === null) return;
    this.scheduler.runBatch().catch(() => {});
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
    DirectoryMonitor.getInstance().stopAll();
    if (this.scheduleTimer !== -1) clearInterval(this.scheduleTimer);
    if (this.chargeSubscriber !== null) commonEventManager.unsubscribe(this.chargeSubscriber);
    if (this.monitorDebounceTimer !== -1) clearTimeout(this.monitorDebounceTimer);
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
    if (this.scheduler !== null) this.scheduler.runBatch().catch(() => {});
  }

  onBackground(): void {
    // Ability has back to background
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onBackground');
  }
}
