import picker from '@ohos.file.picker';
import fs from '@ohos.file.fs';
import preferences from '@ohos.data.preferences';
import zlib from '@ohos.zlib';
import curves from '@ohos.curves';
import { common } from '@kit.AbilityKit';
import router from '@ohos.router';
import { image } from '@kit.ImageKit';
import { textRecognition } from '@kit.CoreVisionKit';
import { pdfService } from '@kit.PDFKit';

interface CategoryItem {
  name: string;
  color: string;
  icon: string;
  subtitle: string;
}

interface FileItem {
  id: number;
  name: string;
  kind: string;
  size: string;
  updated: string;
  tag: string;
  color: string;
  icon: string;
  uri: string;
  extension: string;
  contentText: string;
  parseStatus: string;
  parseSource: string;
  manualTag: boolean;
  importedAt: number;
  organizedAt: number;
}

interface SmartRule {
  id: number;
  name: string;
  titleKeywords: string;
  contentKeywords: string;
  formats: string;
  targetTag: string;
  enabled: boolean;
  isDefault: boolean;
}

interface ContentExtraction {
  text: string;
  status: string;
  source: string;
}

@Entry
@Component
struct Index {
  private preferenceStore: preferences.Preferences | undefined = undefined;
  @StorageLink('pendingSharedUris') @Watch('onPendingSharedUrisChanged') pendingSharedUris: string = '';
  @StorageLink('pendingCardRoute') @Watch('onPendingCardRouteChanged') pendingCardRoute: string = '';
  @State query: string = '';
  @State selectedFilter: string = '全部';
  @State selectedTab: string = '收纳箱';
  @State showQuickAdd: boolean = false;
  @State showFileAction: boolean = false;
  @State showFileDetail: boolean = false;
  @State showManualConfirm: boolean = false;
  @State showOrganizeSummary: boolean = false;
  @State selectedFileId: number = 0;
  @State selectedFileName: string = '';
  @State fileListRevision: number = 0;
  @State showCategoryEditor: boolean = false;
  @State showCategoryDeleteConfirm: boolean = false;
  @State deletingCategoryName: string = '';
  @State newCategoryName: string = '';
  @State newCategoryColor: string = '#E9F0FF';
  @State newCategoryIcon: string = '◇';
  @State showCategoryRuleOptions: boolean = false;
  @State newCategoryTitleKeywords: string = '';
  @State newCategoryFormats: string = '';
  @State selectedUris: string[] = [];
  @State autoOrganize: boolean = true;
  @State showAllHomeCategories: boolean = false;
  @State scanStatus: string = '等待导入';
  @State scanStatusType: string = 'idle';
  private scanStatusTimer: number = -1;
  @State profileType: string = '通用';
  @State showRuleEditor: boolean = false;
  @State showRuleDeleteConfirm: boolean = false;
  @State showProfileChangeWarning: boolean = false;
  @State pendingProfileType: string = '';
  @State pageOpacity: number = 1;
  @State pageOffset: number = 0;
  @State newFileName: string = '';
  @State editingRuleId: number = 0;
  @State ruleName: string = '';
  @State ruleTitleKeywords: string = '';
  @State ruleContentKeywords: string = '';
  @State ruleFormats: string = '';
  @State ruleTargetTag: string = '工作';
  @State lastOrganizedCount: number = 0;
  @State lastOrganizeChangedCount: number = 0;
  @State lastManualConfirmedCount: number = 0;
  @State pendingManualConfirmIds: number[] = [];
  @State isIndexing: boolean = false;
  @StorageLink('llmConfigured') llmConfigured: boolean = false;
  @State pressedFileId: number = 0;
  @State sortingRuleId: number = 0;
  @State files: FileItem[] = [];
  @State categories: CategoryItem[] = [
    { name: '工作', color: '#E9F0FF', icon: '▤', subtitle: '会议、规范与交付物' },
    { name: '项目', color: '#F3E9FF', icon: '✦', subtitle: '正在推进的事项' },
    { name: '生活', color: '#E5F7EF', icon: '☷', subtitle: '日常计划与清单' },
    { name: '灵感', color: '#E7F5F8', icon: '□', subtitle: '收藏的想法与素材' },
    { name: '待整理', color: '#FFF0DD', icon: '◉', subtitle: '还没有归位的文件' }
  ];
  @State rules: SmartRule[] = [
    { id: 101, name: '工作文档', titleKeywords: '会议,报告,方案,合同,规范,简历', contentKeywords: '', formats: '', targetTag: '工作', enabled: true, isDefault: true },
    { id: 102, name: '生活资料', titleKeywords: '旅行,清单,账单,菜谱,健康', contentKeywords: '', formats: '', targetTag: '生活', enabled: true, isDefault: true },
    { id: 103, name: '图片素材', titleKeywords: '', contentKeywords: '', formats: 'jpg,jpeg,png,heic,gif,svg,raw', targetTag: '灵感', enabled: true, isDefault: true },
    { id: 104, name: '设计与项目包', titleKeywords: '', contentKeywords: '', formats: 'fig,psd,sketch,zip,rar,7z', targetTag: '项目', enabled: true, isDefault: true }
  ];

  aboutToAppear(): void {
    try {
      const context = getContext(this) as common.UIAbilityContext;
      this.preferenceStore = preferences.getPreferencesSync(context, { name: 'file_box_data' });
      const filesValue = this.preferenceStore.getSync('files', '[]');
      const rulesValue = this.preferenceStore.getSync('rules', '[]');
      const categoriesValue = this.preferenceStore.getSync('categories', '[]');
      const profileValue = this.preferenceStore.getSync('profile', '通用');
      const autoValue = this.preferenceStore.getSync('autoOrganize', true);
      if (typeof filesValue === 'string') {
        const savedFiles = JSON.parse(filesValue) as FileItem[];
        this.files = savedFiles.map((file: FileItem) => {
          const restoredFile: FileItem = {
            id: file.id,
            name: file.name,
            kind: file.kind,
            size: file.size,
            updated: file.updated,
            tag: file.tag,
            color: file.color,
            icon: file.icon,
            uri: file.uri,
            extension: file.extension,
            contentText: file.contentText === undefined ? '' : file.contentText,
            parseStatus: file.parseStatus === undefined ? '未读取正文' : file.parseStatus,
            parseSource: file.parseSource === undefined ? 'API 未调用' : file.parseSource,
            manualTag: file.manualTag === undefined ? false : file.manualTag,
            importedAt: file.importedAt === undefined ? 0 : file.importedAt,
            organizedAt: file.organizedAt === undefined ? 0 : file.organizedAt
          };
          return restoredFile;
        });
      }
      if (typeof rulesValue === 'string') {
        const savedRules = JSON.parse(rulesValue) as SmartRule[];
        if (savedRules.length > 0) {
          this.rules = savedRules;
        }
      }
      if (typeof categoriesValue === 'string') {
        const savedCategories = JSON.parse(categoriesValue) as CategoryItem[];
        if (savedCategories.length > 0) {
          this.categories = savedCategories;
        }
      }
      if (typeof profileValue === 'string') {
        this.profileType = profileValue;
      }
      if (typeof autoValue === 'boolean') {
        this.autoOrganize = autoValue;
      }
      const savedDefaultRules: SmartRule[] = this.rules.filter((rule: SmartRule) => rule.isDefault);
      const customRules: SmartRule[] = this.rules.filter((rule: SmartRule) => !rule.isDefault);
      this.categories = this.mergeProfileCategories(this.profileType);
      const defaultTargetTag: string = this.categories.length > 0 ? this.categories[0].name : '待整理';
      this.rules = [
        ...this.normalizeCustomRules(customRules, defaultTargetTag),
        ...this.orderedDefaultRules(this.profileType, savedDefaultRules)
      ];
      this.syncCategoriesWithRules();
      this.applySmartRules();
      this.consumeSharedFiles();
    } catch (error) {
      this.scanStatus = '等待导入';
      this.scanStatusType = 'idle';
    }
  }

  private onPendingSharedUrisChanged(): void {
    this.consumeSharedFiles();
  }

  private flashScanStatus(type: string, message: string): void {
    if (this.scanStatusTimer !== -1) {
      clearTimeout(this.scanStatusTimer);
      this.scanStatusTimer = -1;
    }
    this.scanStatus = message;
    this.scanStatusType = type;
    if (type === 'success' || type === 'error') {
      this.scanStatusTimer = setTimeout(() => {
        this.scanStatusType = 'idle';
        this.scanStatusTimer = -1;
      }, type === 'error' ? 3000 : 2600);
    }
  }

  private onPendingCardRouteChanged(): void {
    if (this.pendingCardRoute.length === 0) {
      return;
    }
    const route: string = this.pendingCardRoute;
    this.pendingCardRoute = '';
    if (route === 'quick-categories') {
      this.switchTab('分类');
    } else if (route === 'recent-files') {
      this.switchTab('收纳箱');
    }
  }

  private consumeSharedFiles(): void {
    if (this.pendingSharedUris.length === 0) {
      return;
    }
    try {
      const sharedUris: string[] = JSON.parse(this.pendingSharedUris) as string[];
      const mergedUris: string[] = [...this.selectedUris];
      sharedUris.forEach((uri: string) => {
        if (uri.length > 0 && !mergedUris.includes(uri)) {
          mergedUris.push(uri);
        }
      });
      this.pendingSharedUris = '';
      if (mergedUris.length > 0) {
        this.selectedUris = mergedUris;
        this.newFileName = this.fileNameFromUri(mergedUris[0]);
        this.showQuickAdd = true;
      }
    } catch (error) {
      this.pendingSharedUris = '';
      this.flashScanStatus('error', '没有读取到分享的文件');
    }
  }

  private persistState(): void {
    if (this.preferenceStore === undefined) {
      return;
    }
    const savedFiles: FileItem[] = this.files.map((file: FileItem) => {
      const savedFile: FileItem = {
        id: file.id,
        name: file.name,
        kind: file.kind,
        size: file.size,
        updated: file.updated,
        tag: file.tag,
        color: file.color,
        icon: file.icon,
        uri: file.uri,
        extension: file.extension,
        contentText: file.contentText,
        parseStatus: file.parseStatus,
        parseSource: file.parseSource,
        manualTag: file.manualTag,
        importedAt: file.importedAt,
        organizedAt: file.organizedAt
      };
      return savedFile;
    });
    try {
      AppStorage.setOrCreate('fileBoxFiles', JSON.stringify(savedFiles));
      this.preferenceStore.putSync('files', JSON.stringify(savedFiles));
      this.preferenceStore.putSync('rules', JSON.stringify(this.rules));
      this.preferenceStore.putSync('categories', JSON.stringify(this.categories));
      this.preferenceStore.putSync('profile', this.profileType);
      this.preferenceStore.putSync('autoOrganize', this.autoOrganize);
      this.preferenceStore.flush().catch(() => {});
    } catch (error) {
      this.flashScanStatus('error', '本地保存失败');
    }
  }

  private visibleFiles(): FileItem[] {
    return this.files.filter((file: FileItem) => {
      const matchesQuery: boolean = this.query.length === 0
        || file.name.toLowerCase().includes(this.query.toLowerCase())
        || file.tag.toLowerCase().includes(this.query.toLowerCase());
      const matchesFilter: boolean = this.selectedFilter === '全部'
        || (this.selectedFilter === '待整理' && file.tag === '待整理')
        || file.kind === this.selectedFilter
        || file.tag === this.selectedFilter;
      return matchesQuery && matchesFilter;
    });
  }

  private categoryCount(label: string): number {
    return this.files.filter((file: FileItem) => file.tag === label).length;
  }

  private monthlyOrganizedCount(): number {
    const now: Date = new Date();
    const monthStart: number = new Date(now.getFullYear(), now.getMonth(), 1).getTime();
    return this.files.filter((file: FileItem) => file.organizedAt >= monthStart).length;
  }

  private profileCategories(profile: string): CategoryItem[] {
    if (profile === '学生') {
      return [
        { name: '课程', color: '#E9F0FF', icon: '▤', subtitle: '课件、讲义与课堂资料' },
        { name: '作业', color: '#F3E9FF', icon: '◇', subtitle: '作业、实验与待提交内容' },
        { name: '证件', color: '#E5F7EF', icon: '□', subtitle: '证明、证书与报名材料' },
        { name: '生活', color: '#E7F5F8', icon: '☷', subtitle: '日常计划与清单' },
        { name: '待整理', color: '#FFF0DD', icon: '◉', subtitle: '还没有归位的文件' }
      ];
    }
    if (profile === '摄影师') {
      return [
        { name: '原片', color: '#E9F0FF', icon: '▤', subtitle: 'RAW、DNG 与相机原片' },
        { name: '视频', color: '#F3E9FF', icon: '✦', subtitle: '拍摄视频与剪辑素材' },
        { name: '交付', color: '#E5F7EF', icon: '□', subtitle: '成片、样片与客户交付' },
        { name: '灵感', color: '#E7F5F8', icon: '◇', subtitle: '参考图、样片与 moodboard' },
        { name: '待整理', color: '#FFF0DD', icon: '◉', subtitle: '还没有归位的文件' }
      ];
    }
    if (profile === '程序员') {
      return [
        { name: '源码', color: '#E9F0FF', icon: '▤', subtitle: '代码、配置与脚本' },
        { name: '文档', color: '#F3E9FF', icon: '□', subtitle: 'README、需求与接口说明' },
        { name: '构建产物', color: '#E5F7EF', icon: '◉', subtitle: '压缩包、安装包与交付文件' },
        { name: '项目', color: '#E7F5F8', icon: '✦', subtitle: '项目资料与协作文件' },
        { name: '待整理', color: '#FFF0DD', icon: '☷', subtitle: '还没有归位的文件' }
      ];
    }
    return [
      { name: '工作', color: '#E9F0FF', icon: '▤', subtitle: '会议、规范与交付物' },
      { name: '项目', color: '#F3E9FF', icon: '✦', subtitle: '正在推进的事项' },
      { name: '生活', color: '#E5F7EF', icon: '☷', subtitle: '日常计划与清单' },
      { name: '灵感', color: '#E7F5F8', icon: '□', subtitle: '收藏的想法与素材' },
      { name: '待整理', color: '#FFF0DD', icon: '◉', subtitle: '还没有归位的文件' }
    ];
  }

  private knownProfileCategoryNames(): string[] {
    return [
      '工作', '项目', '生活', '灵感', '待整理',
      '课程', '作业', '证件',
      '原片', '视频', '交付',
      '源码', '文档', '构建产物'
    ];
  }

  private mergeProfileCategories(profile: string): CategoryItem[] {
    const profileCategories: CategoryItem[] = this.profileCategories(profile);
    const knownNames: string[] = this.knownProfileCategoryNames();
    const customCategories: CategoryItem[] = this.categories.filter((category: CategoryItem) => !knownNames.includes(category.name));
    return [...profileCategories, ...customCategories];
  }

  private categoryTemplate(name: string): CategoryItem {
    const knownCategory: CategoryItem | undefined = this.profileCategories(this.profileType)
      .find((category: CategoryItem) => category.name === name);
    if (knownCategory !== undefined) {
      return knownCategory;
    }
    const savedCategory: CategoryItem | undefined = this.categories.find((category: CategoryItem) => category.name === name);
    if (savedCategory !== undefined) {
      return savedCategory;
    }
    const category: CategoryItem = {
      name: name,
      color: '#E9F0FF',
      icon: '□',
      subtitle: '由整理规则生成'
    };
    return category;
  }

  private syncCategoriesWithRules(): void {
    const categoryNames: string[] = this.categories.map((category: CategoryItem) => category.name);
    const generatedCategories: CategoryItem[] = [];
    this.rules.forEach((rule: SmartRule) => {
      if (rule.targetTag.length > 0 && !categoryNames.includes(rule.targetTag)) {
        categoryNames.push(rule.targetTag);
        generatedCategories.push(this.categoryTemplate(rule.targetTag));
      }
    });
    if (generatedCategories.length > 0) {
      this.categories = [...this.categories, ...generatedCategories];
    }
  }

  private profileRules(profile: string): SmartRule[] {
    if (profile === '学生') {
      return [
        { id: 201, name: '课程资料', titleKeywords: '课程,课堂,笔记,讲义,课件,复习,试卷,教材,习题,资料,语文,英语,数学,物理,化学,生物,政治,历史,地理,电路,原理', contentKeywords: '', formats: 'pdf,doc,docx,ppt,pptx,md,txt', targetTag: '课程', enabled: true, isDefault: true },
        { id: 202, name: '作业与实验', titleKeywords: '作业,实验,报告,论文,提交,题目', contentKeywords: '', formats: '', targetTag: '作业', enabled: true, isDefault: true },
        { id: 203, name: '证件材料', titleKeywords: '证件,证明,证书,报名,身份证,学生证', contentKeywords: '', formats: '', targetTag: '证件', enabled: true, isDefault: true },
        { id: 204, name: '生活资料', titleKeywords: '旅行,清单,账单,健康,宿舍', contentKeywords: '', formats: '', targetTag: '生活', enabled: true, isDefault: true }
      ];
    }
    if (profile === '摄影师') {
      return [
        { id: 301, name: '原片与照片', titleKeywords: '', contentKeywords: '', formats: 'raw,dng,arw,cr2,nef,jpg,jpeg,heic', targetTag: '原片', enabled: true, isDefault: true },
        { id: 302, name: '视频素材', titleKeywords: '', contentKeywords: '', formats: 'mp4,mov,mkv,m4v,avi', targetTag: '视频', enabled: true, isDefault: true },
        { id: 303, name: '交付成片', titleKeywords: '交付,成片,修图,精修,客户,发布', contentKeywords: '', formats: 'jpg,jpeg,png,pdf,zip', targetTag: '交付', enabled: true, isDefault: true },
        { id: 304, name: '灵感参考', titleKeywords: '灵感,参考,样片,moodboard', contentKeywords: '', formats: '', targetTag: '灵感', enabled: true, isDefault: true }
      ];
    }
    if (profile === '程序员') {
      return [
        { id: 401, name: '项目源码', titleKeywords: 'readme,package,build,src,项目', contentKeywords: '', formats: 'md,json,json5,ets,ts,js,java,py,cpp,h,css,html', targetTag: '源码', enabled: true, isDefault: true },
        { id: 402, name: '技术文档', titleKeywords: '接口,设计,规范,文档,会议,需求', contentKeywords: '', formats: 'pdf,doc,docx,ppt,pptx,md,txt', targetTag: '文档', enabled: true, isDefault: true },
        { id: 403, name: '构建产物', titleKeywords: 'release,dist,build,安装包,交付', contentKeywords: '', formats: 'zip,rar,7z,tar,gz,hap,hqf,apk', targetTag: '构建产物', enabled: true, isDefault: true }
      ];
    }
    return [
      { id: 101, name: '工作文档', titleKeywords: '会议,报告,方案,合同,规范,简历', contentKeywords: '', formats: '', targetTag: '工作', enabled: true, isDefault: true },
      { id: 102, name: '生活资料', titleKeywords: '旅行,清单,账单,菜谱,健康', contentKeywords: '', formats: '', targetTag: '生活', enabled: true, isDefault: true },
      { id: 103, name: '图片素材', titleKeywords: '', contentKeywords: '', formats: 'jpg,jpeg,png,heic,gif,svg,raw', targetTag: '灵感', enabled: true, isDefault: true },
      { id: 104, name: '设计与项目包', titleKeywords: '', contentKeywords: '', formats: 'fig,psd,sketch,zip,rar,7z', targetTag: '项目', enabled: true, isDefault: true }
    ];
  }

  private orderedDefaultRules(profile: string, savedDefaultRules: SmartRule[]): SmartRule[] {
    const defaults: SmartRule[] = this.profileRules(profile);
    if (savedDefaultRules.length === 0) {
      return defaults;
    }
    const orderedIds: number[] = savedDefaultRules.map((rule: SmartRule) => rule.id);
    const remainingDefaults: SmartRule[] = defaults.filter((rule: SmartRule) => !orderedIds.includes(rule.id));
    const reorderedDefaults: SmartRule[] = [];
    orderedIds.forEach((id: number) => {
      const rule: SmartRule | undefined = defaults.find((item: SmartRule) => item.id === id);
      if (rule !== undefined) {
        const savedRule: SmartRule | undefined = savedDefaultRules.find((item: SmartRule) => item.id === id);
        const restoredRule: SmartRule = {
          id: rule.id,
          name: rule.name,
          titleKeywords: rule.titleKeywords,
          contentKeywords: rule.contentKeywords,
          formats: rule.formats,
          targetTag: rule.targetTag,
          enabled: savedRule === undefined ? rule.enabled : savedRule.enabled,
          isDefault: rule.isDefault
        };
        reorderedDefaults.push(restoredRule);
      }
    });
    return [...reorderedDefaults, ...remainingDefaults];
  }

  private normalizeCustomRules(customRules: SmartRule[], defaultTargetTag: string): SmartRule[] {
    const categoryNames: string[] = this.categories.map((category: CategoryItem) => category.name);
    return customRules.map((rule: SmartRule) => {
      const normalizedRule: SmartRule = {
        id: rule.id,
        name: rule.name,
        titleKeywords: rule.titleKeywords,
        contentKeywords: rule.contentKeywords,
        formats: rule.formats,
        targetTag: categoryNames.includes(rule.targetTag) ? rule.targetTag : defaultTargetTag,
        enabled: rule.enabled,
        isDefault: rule.isDefault
      };
      return normalizedRule;
    });
  }

  private customRules(): SmartRule[] {
    return this.rules.filter((rule: SmartRule) => !rule.isDefault);
  }

  private defaultRules(): SmartRule[] {
    return this.rules.filter((rule: SmartRule) => rule.isDefault);
  }

  private moveRule(ruleId: number, direction: number): void {
    const targetRule: SmartRule | undefined = this.rules.find((rule: SmartRule) => rule.id === ruleId);
    if (targetRule === undefined) {
      return;
    }
    const customRules: SmartRule[] = this.customRules();
    const defaultRules: SmartRule[] = this.defaultRules();
    const groupRules: SmartRule[] = targetRule.isDefault ? defaultRules : customRules;
    const currentIndex: number = groupRules.findIndex((rule: SmartRule) => rule.id === ruleId);
    const nextIndex: number = currentIndex + direction;
    if (currentIndex < 0 || nextIndex < 0 || nextIndex >= groupRules.length) {
      return;
    }
    const movingRule: SmartRule = groupRules[currentIndex];
    groupRules[currentIndex] = groupRules[nextIndex];
    groupRules[nextIndex] = movingRule;
    this.rules = targetRule.isDefault ? [...customRules, ...groupRules] : [...groupRules, ...defaultRules];
    this.applySmartRules();
  }

  private placeSortingRuleBefore(targetRuleId: number): void {
    if (this.sortingRuleId === 0 || this.sortingRuleId === targetRuleId) {
      this.sortingRuleId = 0;
      return;
    }
    const movingRule: SmartRule | undefined = this.rules.find((rule: SmartRule) => rule.id === this.sortingRuleId);
    const targetRule: SmartRule | undefined = this.rules.find((rule: SmartRule) => rule.id === targetRuleId);
    if (movingRule === undefined || targetRule === undefined || movingRule.isDefault !== targetRule.isDefault) {
      this.sortingRuleId = 0;
      return;
    }
    const customRules: SmartRule[] = this.customRules();
    const defaultRules: SmartRule[] = this.defaultRules();
    const groupRules: SmartRule[] = movingRule.isDefault ? defaultRules : customRules;
    const withoutMoving: SmartRule[] = groupRules.filter((rule: SmartRule) => rule.id !== this.sortingRuleId);
    const targetIndex: number = withoutMoving.findIndex((rule: SmartRule) => rule.id === targetRuleId);
    if (targetIndex < 0) {
      this.sortingRuleId = 0;
      return;
    }
    withoutMoving.splice(targetIndex, 0, movingRule);
    this.rules = movingRule.isDefault ? [...customRules, ...withoutMoving] : [...withoutMoving, ...defaultRules];
    this.sortingRuleId = 0;
    this.applySmartRules();
  }

  private setRuleEnabled(ruleId: number, enabled: boolean): void {
    this.rules = this.rules.map((rule: SmartRule) => {
      if (rule.id === ruleId) {
        const updatedRule: SmartRule = {
          id: rule.id,
          name: rule.name,
          titleKeywords: rule.titleKeywords,
          contentKeywords: rule.contentKeywords,
          formats: rule.formats,
          targetTag: rule.targetTag,
          enabled: enabled,
          isDefault: rule.isDefault
        };
        return updatedRule;
      }
      return rule;
    });
    this.applySmartRules();
  }

  private canPlaceSortingRule(targetRule: SmartRule): boolean {
    if (this.sortingRuleId === 0 || this.sortingRuleId === targetRule.id) {
      return false;
    }
    const movingRule: SmartRule | undefined = this.rules.find((rule: SmartRule) => rule.id === this.sortingRuleId);
    return movingRule !== undefined && movingRule.isDefault === targetRule.isDefault;
  }

  private switchTab(tab: string): void {
    this.pageOpacity = 0.94;
    this.pageOffset = 6;
    animateToImmediately({ curve: curves.springMotion(0.46, 1.0, 0.04) }, () => {
      this.selectedTab = tab;
      this.pageOpacity = 1;
      this.pageOffset = 0;
    });
  }

  private requestProfileChange(profile: string): void {
    if (profile === this.profileType) {
      return;
    }
    this.pendingProfileType = profile;
    this.showProfileChangeWarning = true;
  }

  private cancelProfileChange(): void {
    this.pendingProfileType = '';
    this.showProfileChangeWarning = false;
  }

  private confirmProfileChange(): void {
    const profile: string = this.pendingProfileType;
    this.pendingProfileType = '';
    this.showProfileChangeWarning = false;
    if (profile.length > 0) {
      this.chooseProfile(profile);
    }
  }

  private chooseProfile(profile: string): void {
    const customRules: SmartRule[] = this.rules.filter((rule: SmartRule) => !rule.isDefault);
    const savedDefaultRules: SmartRule[] = this.rules.filter((rule: SmartRule) => rule.isDefault);
    this.profileType = profile;
    this.autoOrganize = true;
    this.categories = this.mergeProfileCategories(profile);
    const defaultTargetTag: string = this.categories.length > 0 ? this.categories[0].name : '待整理';
    const normalizedCustomRules: SmartRule[] = this.normalizeCustomRules(customRules, defaultTargetTag);
    this.selectedFilter = '全部';
    this.ruleTargetTag = defaultTargetTag;
    this.rules = [...normalizedCustomRules, ...this.orderedDefaultRules(profile, savedDefaultRules)];
    this.syncCategoriesWithRules();
    this.applySmartRules();
  }

  private refreshRulesForCurrentProfile(): void {
    const customRules: SmartRule[] = this.customRules();
    const savedDefaultRules: SmartRule[] = this.defaultRules();
    const defaultTargetTag: string = this.categories.length > 0 ? this.categories[0].name : '待整理';
    this.rules = [
      ...this.normalizeCustomRules(customRules, defaultTargetTag),
      ...this.orderedDefaultRules(this.profileType, savedDefaultRules)
    ];
    this.syncCategoriesWithRules();
  }

  private saveCustomRule(): void {
    const name: string = this.ruleName.trim();
    const hasCondition: boolean = this.ruleTitleKeywords.trim().length > 0
      || this.ruleFormats.trim().length > 0;
    if (name.length === 0 || !hasCondition) {
      return;
    }
    const rule: SmartRule = {
      id: this.editingRuleId > 0 ? this.editingRuleId : Date.now(),
      name: name,
      titleKeywords: this.ruleTitleKeywords.trim(),
      contentKeywords: '',
      formats: this.ruleFormats.trim(),
      targetTag: this.ruleTargetTag,
      enabled: true,
      isDefault: this.editingRuleId > 0 && this.rules.some((item: SmartRule) => item.id === this.editingRuleId && item.isDefault)
    };
    if (this.editingRuleId > 0) {
      this.rules = this.rules.map((item: SmartRule) => item.id === this.editingRuleId ? rule : item);
    } else {
      this.rules = [...this.rules, rule];
    }
    this.showRuleEditor = false;
    this.editingRuleId = 0;
    this.ruleName = '';
    this.ruleTitleKeywords = '';
    this.ruleContentKeywords = '';
    this.ruleFormats = '';
    this.applySmartRules();
  }

  private editRule(rule: SmartRule): void {
    this.editingRuleId = rule.id;
    this.ruleName = rule.name;
    this.ruleTitleKeywords = rule.titleKeywords;
    this.ruleContentKeywords = '';
    this.ruleFormats = rule.formats;
    this.ruleTargetTag = rule.targetTag;
    this.showRuleEditor = true;
  }

  private startNewRule(): void {
    this.editingRuleId = 0;
    this.ruleName = '';
    this.ruleTitleKeywords = '';
    this.ruleContentKeywords = '';
    this.ruleFormats = '';
    this.ruleTargetTag = this.categories.length > 0 ? this.categories[0].name : '待整理';
    this.showRuleEditor = true;
  }

  private requestDeleteRule(): void {
    if (this.editingRuleId > 0) {
      this.showRuleDeleteConfirm = true;
    }
  }

  private cancelDeleteRule(): void {
    this.showRuleDeleteConfirm = false;
  }

  private confirmDeleteRule(): void {
    if (this.editingRuleId <= 0) {
      this.showRuleDeleteConfirm = false;
      return;
    }
    const deleteRuleId: number = this.editingRuleId;
    this.rules = this.rules.filter((rule: SmartRule) => rule.id !== deleteRuleId);
    this.showRuleDeleteConfirm = false;
    this.showRuleEditor = false;
    this.editingRuleId = 0;
    this.ruleName = '';
    this.ruleTitleKeywords = '';
    this.ruleContentKeywords = '';
    this.ruleFormats = '';
    this.applySmartRules();
  }

  private requestDeleteCategory(name: string): void {
    if (name === '待整理') {
      return;
    }
    this.deletingCategoryName = name;
    this.showCategoryDeleteConfirm = true;
  }

  private cancelDeleteCategory(): void {
    this.deletingCategoryName = '';
    this.showCategoryDeleteConfirm = false;
  }

  private confirmDeleteCategory(): void {
    const name: string = this.deletingCategoryName;
    if (name.length === 0 || name === '待整理') {
      this.cancelDeleteCategory();
      return;
    }
    const pending: CategoryItem = this.categoryByName('待整理');
    this.categories = this.categories.filter((category: CategoryItem) => category.name !== name);
    this.rules = this.rules.filter((rule: SmartRule) => rule.targetTag !== name);
    this.files = this.files.map((file: FileItem) => {
      if (file.tag === name) {
        const updatedFile: FileItem = {
          id: file.id,
          name: file.name,
          kind: file.kind,
          size: file.size,
          updated: '刚刚移入待整理',
          tag: '待整理',
          color: pending.color,
          icon: pending.icon,
          uri: file.uri,
          extension: file.extension,
          contentText: file.contentText,
          parseStatus: file.parseStatus,
          parseSource: file.parseSource,
          manualTag: false,
          importedAt: file.importedAt,
          organizedAt: file.organizedAt
        };
        return updatedFile;
      }
      return file;
    });
    if (this.selectedFilter === name) {
      this.selectedFilter = '全部';
    }
    if (this.ruleTargetTag === name) {
      this.ruleTargetTag = this.categories.length > 0 ? this.categories[0].name : '待整理';
    }
    this.fileListRevision += 1;
    this.cancelDeleteCategory();
    this.persistState();
  }

  private toggleRule(ruleId: number): void {
    this.rules = this.rules.map((rule: SmartRule) => {
      if (rule.id === ruleId) {
        const toggledRule: SmartRule = {
          id: rule.id,
          name: rule.name,
          titleKeywords: rule.titleKeywords,
          contentKeywords: rule.contentKeywords,
          formats: rule.formats,
          targetTag: rule.targetTag,
          enabled: !rule.enabled,
          isDefault: rule.isDefault
        };
        return toggledRule;
      }
      return rule;
    });
    this.applySmartRules();
  }

  @Builder
  private ruleRow(rule: SmartRule, index: number, total: number) {
    Row() {
      Text('⋮⋮')
        .width(34)
        .height(84)
        .fontSize(20)
        .fontColor(this.sortingRuleId === rule.id ? $r('app.color.accent_green') : (total <= 1 ? '#C8D0DA' : '#9AA8B8'))
        .textAlign(TextAlign.Center)
        .backgroundColor(this.sortingRuleId === rule.id ? '#E5F4EC' : $r('app.color.tint_gray'))
        .borderRadius(12)
        .gesture(
          LongPressGesture({ duration: 450, repeat: false })
            .onAction(() => {
              this.sortingRuleId = rule.id;
            })
        )
      Column() {
        Row() {
          Row({ space: 7 }) {
            Text(rule.name)
              .fontSize(15)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.text_primary'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            Text(rule.isDefault ? '默认' : '自定义')
              .fontSize(10)
              .fontColor(rule.isDefault ? $r('app.color.accent_blue') : $r('app.color.accent_green'))
              .padding({ left: 6, right: 6, top: 2, bottom: 2 })
              .backgroundColor(rule.isDefault ? '#E9F0FF' : '#E5F4EC')
              .borderRadius(6)
          }
          .layoutWeight(1)
        }
        .width('100%')
        Text(this.ruleDescription(rule))
          .fontSize(11)
          .fontColor($r('app.color.text_caption'))
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .margin({ top: 7 })
          .alignSelf(ItemAlign.Start)
        Row({ space: 8 }) {
          Toggle({ type: ToggleType.Switch, isOn: rule.enabled })
            .width(54)
            .height(30)
            .selectedColor($r('app.color.accent_green'))
            .onChange((isOn: boolean) => {
              this.setRuleEnabled(rule.id, isOn);
            })
          Text(rule.enabled ? '已启用' : '停用中')
            .fontSize(12)
            .fontColor(rule.enabled ? $r('app.color.accent_green') : $r('app.color.text_disabled'))
            .fontWeight(FontWeight.Medium)
            .width(48)
          if (this.sortingRuleId === rule.id) {
            Button('完成')
              .width(56)
              .height(34)
              .fontSize(12)
              .fontColor($r('app.color.accent_green'))
              .backgroundColor('#E5F4EC')
              .borderRadius(10)
              .onClick(() => { this.sortingRuleId = 0; })
          } else if (this.canPlaceSortingRule(rule)) {
            Button('移到这里')
              .width(76)
              .height(34)
              .fontSize(12)
              .fontColor($r('app.color.accent_blue'))
              .backgroundColor('#E9F0FF')
              .borderRadius(10)
              .onClick(() => { this.placeSortingRuleBefore(rule.id); })
          } else {
            Button('编辑')
              .width(56)
              .height(34)
              .fontSize(12)
              .fontColor($r('app.color.accent_blue'))
              .backgroundColor('#E9F0FF')
              .borderRadius(10)
              .onClick(() => { this.editRule(rule); })
          }
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
        .margin({ top: 12 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      .margin({ left: 12 })
    }
    .alignItems(VerticalAlign.Center)
    .width('100%')
    .padding({ left: 16, right: 16, top: 15, bottom: 15 })
    .backgroundColor($r('app.color.card_bg'))
    .borderRadius(18)
    .shadow({ radius: 8, color: $r('app.color.shadow_card'), offsetX: 0, offsetY: 2 })
  }

  @Builder
  private ruleSection(title: string, rules: SmartRule[]) {
    Text(title)
      .fontSize(13)
      .fontWeight(FontWeight.Medium)
      .fontColor($r('app.color.text_caption'))
      .alignSelf(ItemAlign.Start)
      .margin({ left: 22, top: 6, bottom: 8 })
    if (rules.length === 0) {
      Text('暂无规则')
        .fontSize(12)
        .fontColor($r('app.color.text_disabled'))
        .alignSelf(ItemAlign.Start)
        .margin({ left: 22, bottom: 10 })
    } else {
      Column({ space: 10 }) {
        ForEach(rules, (rule: SmartRule, index: number) => {
          this.ruleRow(rule, index, rules.length)
        }, (rule: SmartRule) => `${rule.id}-${rule.enabled ? 'on' : 'off'}`)
      }
      .width('100%')
      .padding({ left: 20, right: 20, bottom: 12 })
    }
  }

  private splitKeywords(value: string): string[] {
    return value.replace(/，/g, ',').split(',')
      .map((item: string) => item.trim().toLowerCase())
      .filter((item: string) => item.length > 0);
  }

  private fieldMatches(value: string, condition: string): boolean {
    const keywords: string[] = this.splitKeywords(condition);
    if (keywords.length === 0) {
      return true;
    }
    const source: string = value.toLowerCase();
    return keywords.some((keyword: string) => source.includes(keyword));
  }

  private ruleMatches(file: FileItem, rule: SmartRule): boolean {
    if (!rule.enabled) {
      return false;
    }
    const hasCondition: boolean = rule.titleKeywords.length > 0 || rule.formats.length > 0;
    const extension: string = file.extension.length > 0
      ? file.extension.toLowerCase()
      : this.extensionFromName(file.name);
    return hasCondition
      && this.fieldMatches(file.name, rule.titleKeywords)
      && this.fieldMatches(extension, rule.formats);
  }

  private matchingRuleFor(file: FileItem): SmartRule | undefined {
    const categoryNames: string[] = this.categories.map((category: CategoryItem) => category.name);
    return this.rules.find((rule: SmartRule) => this.ruleMatches(file, rule) && categoryNames.includes(rule.targetTag));
  }

  private matchingRulesFor(file: FileItem): SmartRule[] {
    return this.rules.filter((rule: SmartRule) => this.ruleMatches(file, rule));
  }

  private matchingTargetTags(file: FileItem): string[] {
    const categoryNames: string[] = this.categories.map((category: CategoryItem) => category.name);
    const targetTags: string[] = [];
    this.matchingRulesFor(file).forEach((rule: SmartRule) => {
      if (categoryNames.includes(rule.targetTag) && !targetTags.includes(rule.targetTag)) {
        targetTags.push(rule.targetTag);
      }
    });
    return targetTags;
  }

  private needsManualConfirmation(file: FileItem): boolean {
    const categoryNames: string[] = this.categories.map((category: CategoryItem) => category.name);
    const hasCurrentCategory: boolean = categoryNames.includes(file.tag);
    const keepManualTag: boolean = file.manualTag && hasCurrentCategory && file.tag !== '待整理';
    if (keepManualTag) {
      return false;
    }
    const matched: SmartRule | undefined = this.matchingRuleFor(file);
    const targetTags: string[] = this.matchingTargetTags(file);
    return file.tag === '待整理' && (matched === undefined || !categoryNames.includes(matched.targetTag) || targetTags.length !== 1);
  }

  private collectManualConfirmIds(): number[] {
    return this.files
      .filter((file: FileItem) => this.needsManualConfirmation(file))
      .map((file: FileItem) => file.id);
  }

  private categoryByName(name: string): CategoryItem {
    const category: CategoryItem | undefined = this.categories.find((item: CategoryItem) => item.name === name);
    return category === undefined
      ? { name: '待整理', color: '#FFF0DD', icon: '◉', subtitle: '' }
      : category;
  }

  private organizeFile(file: FileItem): FileItem {
    const categoryNames: string[] = this.categories.map((category: CategoryItem) => category.name);
    const hasCurrentCategory: boolean = categoryNames.includes(file.tag);
    const keepManualTag: boolean = file.manualTag && hasCurrentCategory && file.tag !== '待整理';
    const extension: string = file.extension.length > 0
      ? file.extension.toLowerCase()
      : this.extensionFromName(file.name);
    let targetTag: string = keepManualTag ? file.tag : '待整理';
    if (this.autoOrganize && !keepManualTag) {
      const targetTags: string[] = this.matchingTargetTags(file);
      const matched: SmartRule | undefined = targetTags.length === 1 ? this.matchingRuleFor(file) : undefined;
      if (matched !== undefined && categoryNames.includes(matched.targetTag) && targetTags.length === 1) {
        targetTag = matched.targetTag;
      }
    }
    const category: CategoryItem = this.categoryByName(targetTag);
    const organizedFile: FileItem = {
      id: file.id,
      name: file.name,
      kind: file.kind,
      size: file.size,
      updated: file.updated,
      tag: targetTag,
      color: category.color,
      icon: category.icon,
      uri: file.uri,
      extension: extension,
      contentText: file.contentText,
      parseStatus: file.parseStatus,
      parseSource: file.parseSource,
      manualTag: keepManualTag,
      importedAt: file.importedAt,
      organizedAt: targetTag !== '待整理' && file.organizedAt === 0 ? Date.now() : file.organizedAt
    };
    return organizedFile;
  }

  private applySmartRules(): void {
    if (!this.autoOrganize) {
      this.flashScanStatus('success', '自动整理已暂停');
      this.persistState();
      return;
    }
    let organized: number = 0;
    let changed: number = 0;
    this.files = this.files.map((file: FileItem) => {
      const result: FileItem = this.organizeFile(file);
      if (result.tag !== '待整理') {
        organized++;
      }
      if (result.tag !== file.tag) {
        changed++;
      }
      return result;
    });
    this.lastOrganizedCount = organized;
    this.lastOrganizeChangedCount = changed;
    if (this.files.length === 0) {
      this.flashScanStatus('idle', '等待导入');
    } else {
      this.flashScanStatus('success', `已整理 ${organized} 个`);
    }
    this.persistState();
  }

  private runAutoOrganize(): void {
    this.autoOrganize = true;
    this.selectedFilter = '全部';
    this.categories = this.mergeProfileCategories(this.profileType);
    this.refreshRulesForCurrentProfile();
    this.applySmartRules();
    this.pendingManualConfirmIds = this.collectManualConfirmIds();
    this.lastManualConfirmedCount = 0;
    if (this.pendingManualConfirmIds.length > 0) {
      this.showManualConfirm = true;
      this.showOrganizeSummary = false;
    } else {
      this.showManualConfirm = false;
      this.showOrganizeSummary = true;
    }
  }

  private manualConfirmFiles(): FileItem[] {
    return this.files.filter((file: FileItem) => this.pendingManualConfirmIds.includes(file.id));
  }

  private chooseManualConfirmTag(fileId: number, tag: string): void {
    const category: CategoryItem = this.categoryByName(tag);
    let changed: boolean = false;
    this.files = this.files.map((file: FileItem) => {
      if (file.id === fileId) {
        changed = file.tag !== tag;
        const updatedFile: FileItem = {
          id: file.id,
          name: file.name,
          kind: file.kind,
          size: file.size,
          updated: tag === '待整理' ? file.updated : '刚刚归纳',
          tag: tag,
          color: category.color,
          icon: category.icon,
          uri: file.uri,
          extension: file.extension,
          contentText: file.contentText,
          parseStatus: file.parseStatus,
          parseSource: file.parseSource,
          manualTag: tag !== '待整理',
          importedAt: file.importedAt,
          organizedAt: tag !== '待整理' && file.organizedAt === 0 ? Date.now() : file.organizedAt
        };
        return updatedFile;
      }
      return file;
    });
    this.pendingManualConfirmIds = this.pendingManualConfirmIds.filter((id: number) => id !== fileId);
    if (changed) {
      this.lastOrganizeChangedCount += 1;
    }
    if (tag !== '待整理') {
      this.lastManualConfirmedCount += 1;
      this.lastOrganizedCount = this.files.filter((file: FileItem) => file.tag !== '待整理').length;
    }
    this.fileListRevision += 1;
    this.persistState();
    if (this.pendingManualConfirmIds.length === 0) {
      this.finishManualConfirmation();
    }
  }

  private finishManualConfirmation(): void {
    this.showManualConfirm = false;
    this.pendingManualConfirmIds = [];
    this.lastOrganizedCount = this.files.filter((file: FileItem) => file.tag !== '待整理').length;
    if (this.files.length === 0) {
      this.flashScanStatus('idle', '等待导入');
    } else {
      this.flashScanStatus('success', `已整理 ${this.lastOrganizedCount} 个`);
    }
    this.persistState();
    this.showOrganizeSummary = true;
  }

  private ruleDescription(rule: SmartRule): string {
    let description: string = '';
    if (rule.titleKeywords.length > 0) {
      description = `标题含「${rule.titleKeywords}」`;
    }
    if (rule.formats.length > 0) {
      description += `${description.length > 0 ? ' · ' : ''}格式 ${rule.formats}`;
    }
    return `${description} → ${rule.targetTag}`;
  }

  private openFile(file: FileItem): void {
    if (file.uri.length === 0) {
      this.presentTagEditor(file.id);
      return;
    }
    const context = getContext(this) as common.UIAbilityContext;
    context.startAbility({
      action: 'ohos.want.action.viewData',
      uri: file.uri
    }).catch(() => {
      this.flashScanStatus('error', `无法打开「${file.name}」`);
    });
  }

  private presentFileAction(file: FileItem): void {
    this.selectedFileId = file.id;
    this.selectedFileName = file.name;
    this.showFileDetail = false;
    this.showFileAction = true;
  }

  private presentTagEditor(fileId: number): void {
    const currentFile: FileItem | undefined = this.files.find((item: FileItem) => item.id === fileId);
    if (currentFile === undefined) {
      return;
    }
    this.selectedFileId = currentFile.id;
    this.selectedFileName = currentFile.name;
    this.showFileAction = false;
    this.showFileDetail = true;
  }

  private handleFileTap(file: FileItem): void {
    const currentFile: FileItem | undefined = this.files.find((item: FileItem) => item.id === file.id);
    if (currentFile === undefined) {
      return;
    }
    this.selectedFileId = currentFile.id;
    this.selectedFileName = currentFile.name;
    if (currentFile.tag === '待整理') {
      this.presentFileAction(currentFile);
    } else {
      this.openFile(currentFile);
    }
  }

  private addCategory(): void {
    const name = this.newCategoryName.trim();
    if (name.length === 0 || this.categories.some((category: CategoryItem) => category.name === name)) {
      return;
    }
    const titleKeywords: string = this.newCategoryTitleKeywords.trim();
    const formats: string = this.newCategoryFormats.trim();
    const category: CategoryItem = {
      name: name,
      color: this.newCategoryColor,
      icon: this.newCategoryIcon,
      subtitle: '自定义分类'
    };
    this.categories = [...this.categories, category];
    const hasRuleCondition: boolean = titleKeywords.length > 0 || formats.length > 0;
    if (hasRuleCondition) {
      const rule: SmartRule = {
        id: Date.now(),
        name: name,
        titleKeywords: titleKeywords,
        contentKeywords: '',
        formats: formats,
        targetTag: name,
        enabled: true,
        isDefault: false
      };
      this.rules = [...this.rules, rule];
    }
    this.newCategoryName = '';
    this.newCategoryTitleKeywords = '';
    this.newCategoryFormats = '';
    this.showCategoryRuleOptions = false;
    this.showCategoryEditor = false;
    this.applySmartRules();
    this.persistState();
  }

  private fileNameFromUri(uri: string): string {
    const cleanUri: string = uri.split('?')[0];
    const separatorIndex: number = cleanUri.lastIndexOf('/');
    const encodedName: string = separatorIndex >= 0 ? cleanUri.substring(separatorIndex + 1) : cleanUri;
    try {
      return decodeURIComponent(encodedName);
    } catch (error) {
      return encodedName.length > 0 ? encodedName : '未命名文件';
    }
  }

  private extensionFromName(name: string): string {
    const dotIndex: number = name.lastIndexOf('.');
    return dotIndex > 0 && dotIndex < name.length - 1 ? name.substring(dotIndex + 1).toLowerCase() : '';
  }

  private kindFromExtension(extension: string): string {
    if (['jpg', 'jpeg', 'png', 'heic', 'gif', 'svg', 'raw', 'dng', 'arw', 'cr2', 'nef'].includes(extension)) {
      return '图片';
    }
    if (['mp3', 'm4a', 'wav', 'flac', 'aac'].includes(extension)) {
      return '音频';
    }
    if (['mp4', 'mov', 'mkv', 'm4v', 'avi'].includes(extension)) {
      return '视频';
    }
    if (['zip', 'rar', '7z', 'tar', 'gz'].includes(extension)) {
      return '压缩包';
    }
    if (['fig', 'psd', 'sketch'].includes(extension)) {
      return '设计';
    }
    return '文档';
  }

  private formatSize(bytes: number): string {
    if (bytes < 1024) {
      return `${bytes} B`;
    }
    if (bytes < 1024 * 1024) {
      return `${(bytes / 1024).toFixed(1)} KB`;
    }
    if (bytes < 1024 * 1024 * 1024) {
      return `${(bytes / 1024 / 1024).toFixed(1)} MB`;
    }
    return `${(bytes / 1024 / 1024 / 1024).toFixed(1)} GB`;
  }

  private sizeOfFile(uri: string): string {
    try {
      return this.formatSize(fs.statSync(uri).size);
    } catch (error) {
      return '大小未知';
    }
  }

  private extraction(text: string, status: string, source: string): ContentExtraction {
    const result: ContentExtraction = {
      text: text.length > 32000 ? text.substring(0, 32000) : text,
      status: status,
      source: source
    };
    return result;
  }

  private stripXml(xml: string): string {
    return xml
      .replace(/<w:tab\s*\/?>/g, ' ')
      .replace(/<a:br\s*\/?>/g, '\n')
      .replace(/<[^>]+>/g, ' ')
      .replace(/&amp;/g, '&')
      .replace(/&lt;/g, '<')
      .replace(/&gt;/g, '>')
      .replace(/&quot;/g, '"')
      .replace(/&#39;/g, "'")
      .replace(/\s+/g, ' ')
      .trim();
  }

  private createWorkDirectory(prefix: string): string {
    const context = getContext(this) as common.UIAbilityContext;
    const directory: string = `${context.cacheDir}/${prefix}_${Date.now()}_${Math.floor(Math.random() * 10000)}`;
    fs.mkdirSync(directory, true);
    return directory;
  }

  private copyAuthorizedFile(uri: string, destination: string): void {
    const sourceFile = fs.openSync(uri, fs.OpenMode.READ_ONLY);
    try {
      fs.copyFileSync(sourceFile.fd, destination);
    } finally {
      fs.closeSync(sourceFile);
    }
  }

  private deleteWorkDirectory(path: string): void {
    try {
      const entries: string[] = fs.listFileSync(path);
      entries.forEach((entry: string) => {
        const child: string = `${path}/${entry}`;
        if (fs.statSync(child).isDirectory()) {
          this.deleteWorkDirectory(child);
        } else {
          fs.unlinkSync(child);
        }
      });
      fs.rmdirSync(path);
    } catch (error) {
    }
  }

  private extractPlainText(uri: string): ContentExtraction {
    try {
      const text: string = fs.readTextSync(uri, { length: 32000 });
      return this.extraction(text, text.length > 0 ? '文本已索引' : '没有可索引文字', '文本');
    } catch (error) {
      return this.extraction('', '文本读取失败', '文本');
    }
  }

  private async recognizePixelMap(pixelMap: image.PixelMap): Promise<string> {
    const visionInfo: textRecognition.VisionInfo = { pixelMap: pixelMap };
    const result: textRecognition.TextRecognitionResult = await textRecognition.recognizeText(visionInfo, {
      isDirectionDetectionSupported: true
    });
    return result.value;
  }

  private async extractImageText(uri: string): Promise<ContentExtraction> {
    let pixelMap: image.PixelMap | undefined = undefined;
    let imageSource: image.ImageSource | undefined = undefined;
    try {
      imageSource = image.createImageSource(uri);
      const initialized: boolean = await textRecognition.init();
      if (!initialized) {
        return this.extraction('', 'OCR 服务不可用', 'OCR');
      }
      pixelMap = await imageSource.createPixelMap();
      const text: string = await this.recognizePixelMap(pixelMap);
      return this.extraction(text, text.trim().length > 0 ? 'OCR 已完成' : '图片中未识别到文字', '图片 OCR');
    } catch (error) {
      return this.extraction('', 'OCR 识别失败', 'OCR');
    } finally {
      if (pixelMap !== undefined) {
        pixelMap.release();
      }
      if (imageSource !== undefined) {
        imageSource.release();
      }
      textRecognition.release().catch(() => {});
    }
  }

  private async extractOfficeText(uri: string, extension: string): Promise<ContentExtraction> {
    const workDirectory: string = this.createWorkDirectory('office_parse');
    const archivePath: string = `${workDirectory}/source.${extension}`;
    const outputDirectory: string = `${workDirectory}/content`;
    try {
      this.copyAuthorizedFile(uri, archivePath);
      fs.mkdirSync(outputDirectory, true);
      await zlib.decompressFile(archivePath, outputDirectory);
      const entries: string[] = fs.listFileSync(outputDirectory, { recursion: true }).sort();
      let text: string = '';
      for (let index: number = 0; index < entries.length && text.length < 32000; index++) {
        const relativePath: string = entries[index].replace(/\\/g, '/');
        const isWordXml: boolean = extension === 'docx' && relativePath.includes('/word/') && relativePath.endsWith('.xml');
        const isPowerPointXml: boolean = extension === 'pptx'
          && (relativePath.includes('/ppt/slides/slide') || relativePath.includes('/ppt/notesSlides/'))
          && relativePath.endsWith('.xml');
        const isExcelXml: boolean = extension === 'xlsx'
          && (relativePath.includes('/xl/sharedStrings.xml') || relativePath.includes('/xl/worksheets/'))
          && relativePath.endsWith('.xml');
        if (isWordXml || isPowerPointXml || isExcelXml) {
          const xmlPath: string = relativePath.startsWith('/')
            ? outputDirectory + relativePath
            : `${outputDirectory}/${relativePath}`;
          text += ` ${this.stripXml(fs.readTextSync(xmlPath, { length: 128000 }))}`;
        }
      }
      return this.extraction(text.trim(), text.trim().length > 0 ? 'Office 正文已索引' : 'Office 文档没有可索引文字', 'Office 文档');
    } catch (error) {
      return this.extraction('', 'Office 文档解析失败', 'Office 文档');
    } finally {
      this.deleteWorkDirectory(workDirectory);
    }
  }

  private async extractPdfText(uri: string): Promise<ContentExtraction> {
    const workDirectory: string = this.createWorkDirectory('pdf_parse');
    const localPath: string = `${workDirectory}/source.pdf`;
    let document: pdfService.PdfDocument | undefined = undefined;
    let ocrInitialized: boolean = false;
    let loaded: boolean = false;
    let stage: string = '读取文件';
    try {
      this.copyAuthorizedFile(uri, localPath);
      stage = '启动 PDF 服务';
      document = new pdfService.PdfDocument();
      stage = '加载 PDF';
      const parseResult: pdfService.ParseResult = document.loadDocument(localPath);
      if (parseResult !== pdfService.ParseResult.PARSE_SUCCESS) {
        return this.extraction('', parseResult === pdfService.ParseResult.PARSE_ERROR_PASSWORD ? 'PDF 需要密码' : 'PDF 解析失败', 'PDF');
      }
      loaded = true;
      const pageCount: number = Math.min(document.getPageCount(), 30);
      let text: string = '';
      let usedOcr: boolean = false;
      for (let index: number = 0; index < pageCount && text.length < 32000; index++) {
        const page: pdfService.PdfPage = document.getPage(index);
        try {
          let pageText: string = page.getTextContent().trim();
          if (pageText.length === 0) {
            if (!ocrInitialized) {
              ocrInitialized = await textRecognition.init();
            }
            if (ocrInitialized) {
              const pagePixelMap: image.PixelMap = page.getPagePixelMap();
              try {
                pageText = await this.recognizePixelMap(pagePixelMap);
                usedOcr = true;
              } finally {
                pagePixelMap.release();
              }
            }
          }
          text += ` ${pageText}`;
        } finally {
          page.release();
        }
      }
      const source: string = usedOcr ? 'PDF 文本 + OCR' : 'PDF 文本层';
      const status: string = text.trim().length > 0
        ? (document.getPageCount() > 30 ? 'PDF 前 30 页已索引' : 'PDF 正文已索引')
        : 'PDF 中未识别到文字';
      return this.extraction(text.trim(), status, source);
    } catch (error) {
      return this.extraction('', `${stage}失败`, stage === '启动 PDF 服务' ? '虚拟机可能不支持 PDFKit' : 'PDF');
    } finally {
      if (ocrInitialized) {
        textRecognition.release().catch(() => {});
      }
      if (loaded && document !== undefined) {
        document.releaseDocument();
      }
      this.deleteWorkDirectory(workDirectory);
    }
  }

  private async extractContent(uri: string, extension: string): Promise<ContentExtraction> {
    const plainExtensions: string[] = ['txt', 'md', 'csv', 'json', 'json5', 'xml', 'html', 'log', 'ets', 'ts', 'js', 'java', 'py', 'cpp', 'h'];
    const imageExtensions: string[] = ['jpg', 'jpeg', 'png', 'heic', 'gif', 'bmp', 'webp'];
    try {
      if (plainExtensions.includes(extension)) {
        return this.extractPlainText(uri);
      }
      if (imageExtensions.includes(extension)) {
        return await this.extractImageText(uri);
      }
      if (['docx', 'pptx', 'xlsx'].includes(extension)) {
        return await this.extractOfficeText(uri, extension);
      }
      if (extension === 'pdf') {
        return await this.extractPdfText(uri);
      }
      return this.extraction('', '仅按标题和格式整理', '未解析正文');
    } catch (error) {
      return this.extraction('', '文档解析失败', '解析器');
    }
  }

  async parseDocumentContent(uri: string, extension: string = ''): Promise<ContentExtraction> {
    const normalizedExtension: string = extension.length > 0
      ? extension.toLowerCase()
      : this.extensionFromName(this.fileNameFromUri(uri));
    return await this.extractContent(uri, normalizedExtension);
  }

  private async addFile(): Promise<void> {
    if (this.selectedUris.length === 0) {
      this.showQuickAdd = false;
      return;
    }
    this.isIndexing = true;
    const newFiles: FileItem[] = [];
    for (let index: number = 0; index < this.selectedUris.length; index++) {
      const uri: string = this.selectedUris[index];
      if (!this.files.some((file: FileItem) => file.uri === uri)) {
        this.flashScanStatus('progress', `正在导入 ${index + 1}/${this.selectedUris.length}`);
        const name: string = this.fileNameFromUri(uri);
        const extension: string = this.extensionFromName(name);
        const pending: CategoryItem = this.categoryByName('待整理');
        const newFile: FileItem = {
          id: Date.now() + index,
          name: name,
          kind: this.kindFromExtension(extension),
          size: this.sizeOfFile(uri),
          updated: '刚刚导入',
          tag: '待整理',
          color: pending.color,
          icon: pending.icon,
          uri: uri,
          extension: extension,
          contentText: '',
          parseStatus: '未读取正文',
          parseSource: 'API 未调用',
          manualTag: false,
          importedAt: Date.now(),
          organizedAt: 0
        };
        newFiles.push(newFile);
      }
    }
    this.files = [...newFiles, ...this.files];
    this.newFileName = '';
    this.selectedUris = [];
    this.showQuickAdd = false;
    this.selectedFilter = '全部';
    this.isIndexing = false;
    this.applySmartRules();
  }

  private selectFile(): void {
    const documentPicker = new picker.DocumentViewPicker();
    documentPicker.select({
      maxSelectNumber: 100
    }).then((uris: Array<string>) => {
      if (uris.length > 0) {
        const mergedUris: string[] = [...this.selectedUris];
        uris.forEach((uri: string) => {
          if (!mergedUris.includes(uri)) {
            mergedUris.push(uri);
          }
        });
        this.selectedUris = mergedUris;
        this.newFileName = this.fileNameFromUri(mergedUris[0]);
      }
    }).catch(() => {});
  }

  private retagSelected(tag: string): void {
    const category: CategoryItem = this.categoryByName(tag);
    const updatedFiles: FileItem[] = this.files.map((file: FileItem) => {
      if (file.id === this.selectedFileId) {
        const updatedFile: FileItem = {
          id: file.id,
          name: file.name,
          kind: file.kind,
          size: file.size,
          updated: '刚刚归纳',
          tag: tag,
          color: category.color,
          icon: category.icon,
          uri: file.uri,
          extension: file.extension,
          contentText: file.contentText,
          parseStatus: file.parseStatus,
          parseSource: file.parseSource,
          manualTag: true,
          importedAt: file.importedAt,
          organizedAt: file.organizedAt === 0 ? Date.now() : file.organizedAt
        };
        return updatedFile;
      }
      return file;
    });
    this.files = [...updatedFiles];
    this.fileListRevision += 1;
    this.showFileAction = false;
    this.showFileDetail = false;
    this.selectedFilter = '全部';
    this.persistState();
  }

  @Builder
  private categoryCard(label: string, subtitle: string, color: string, icon: string) {
    Row() {
      Text(icon)
        .fontSize(22)
        .fontColor($r('app.color.accent_blue'))
        .width(46)
        .height(46)
        .textAlign(TextAlign.Center)
        .backgroundColor(color)
        .borderRadius(15)
      Column() {
        Text(label)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
        Text(subtitle)
          .fontSize(12)
          .fontColor($r('app.color.text_caption'))
          .margin({ top: 4 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      .margin({ left: 12 })
      Text(`${this.categoryCount(label)} 项`)
        .fontSize(13)
        .fontColor($r('app.color.text_caption'))
      Text('›')
        .fontSize(22)
        .fontColor($r('app.color.text_disabled'))
        .margin({ left: 5 })
    }
    .width('100%')
    .padding({ left: 14, right: 14, top: 13, bottom: 13 })
    .backgroundColor($r('app.color.card_bg'))
    .borderRadius(19)
    .shadow({ radius: 8, color: $r('app.color.shadow_card'), offsetX: 0, offsetY: 2 })
    .gesture(
      GestureGroup(GestureMode.Exclusive,
        LongPressGesture({ duration: 450, repeat: false })
          .onAction(() => {
            this.requestDeleteCategory(label);
          }),
        TapGesture()
          .onAction(() => {
            this.selectedFilter = label;
            this.switchTab('收纳箱');
          })
      )
    )
  }

  @Builder
  private filterChip(label: string) {
    Text(label)
      .fontSize(14)
      .fontColor(this.selectedFilter === label ? Color.White : $r('app.color.text_body'))
      .fontWeight(this.selectedFilter === label ? FontWeight.Medium : FontWeight.Regular)
      .textAlign(TextAlign.Center)
      .padding({ left: 16, right: 16, top: 9, bottom: 9 })
      .backgroundColor(this.selectedFilter === label ? $r('app.color.accent_primary') : $r('app.color.tint_gray'))
      .borderRadius(18)
      .onClick(() => {
        this.selectedFilter = label;
      });
  }

  @Builder
  private homeCategoryChip(category: CategoryItem) {
    Text(`${category.name} ${this.categoryCount(category.name)}`)
      .fontSize(15)
      .fontWeight(FontWeight.Bold)
      .fontColor(category.name === '待整理' ? $r('app.color.accent_amber') : $r('app.color.accent_blue'))
      .padding({ left: 15, right: 15, top: 9, bottom: 9 })
      .backgroundColor(category.color)
      .borderRadius(19)
      .margin({ right: 10, bottom: 10 })
      .onClick(() => {
        this.selectedFilter = category.name;
      })
  }

  @Builder
  private homeAllFilesChip() {
    Text(`全部文件 ${this.files.length}`)
      .fontSize(15)
      .fontWeight(FontWeight.Bold)
      .fontColor(this.selectedFilter === '全部' ? $r('app.color.card_bg') : $r('app.color.accent_primary'))
      .padding({ left: 15, right: 15, top: 9, bottom: 9 })
      .backgroundColor(this.selectedFilter === '全部' ? $r('app.color.accent_primary') : $r('app.color.tint_gray'))
      .borderRadius(19)
      .margin({ right: 10, bottom: 10 })
      .onClick(() => {
        this.selectedFilter = '全部';
      })
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Scroll() {
        Column({ space: 0 }) {
          Column() {
            Text('拾序')
              .fontSize(40)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text_primary'))
              .alignSelf(ItemAlign.Start)
            Text('让每个文件，都有自己的位置')
              .fontSize(17)
              .fontColor($r('app.color.text_caption'))
              .alignSelf(ItemAlign.Start)
              .margin({ top: 7 })
          }
          .width('100%')
          .padding({ left: 32, right: 26, top: 23, bottom: 18 })

          Column() {
            Row() {
              Text('自动整理')
                .fontSize(20)
                .fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.text_primary'))
              Blank()
              Button('立即整理')
                .height(40)
                .fontSize(14)
                .fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.accent_green'))
                .padding({ left: 18, right: 18 })
                .backgroundColor('#E5F4EC')
                .borderRadius(20)
                .onClick(() => {
                  this.runAutoOrganize();
                })
            }
            .width('100%')
            .alignItems(VerticalAlign.Center)
            Flex({ wrap: FlexWrap.Wrap }) {
              this.homeAllFilesChip()
              ForEach(this.categories, (category: CategoryItem, index: number) => {
                if (this.showAllHomeCategories || index < 4) {
                  this.homeCategoryChip(category)
                }
              }, (category: CategoryItem) => category.name)
              if (this.categories.length > 4) {
                Text(this.showAllHomeCategories ? '收起' : `更多 ${this.categories.length - 4}`)
                  .fontSize(15)
                  .fontWeight(FontWeight.Bold)
                  .fontColor($r('app.color.text_body'))
                  .padding({ left: 15, right: 15, top: 9, bottom: 9 })
                  .backgroundColor($r('app.color.tint_gray'))
                  .borderRadius(19)
                  .margin({ right: 10, bottom: 10 })
                  .onClick(() => {
                    this.showAllHomeCategories = !this.showAllHomeCategories;
                  })
              }
            }
            .width('100%')
            .margin({ top: 18 })
          }
          .width('100%')
          .padding({ left: 24, right: 24, top: 28, bottom: 25 })
          .backgroundColor($r('app.color.card_bg'))
          .borderRadius(34)
          .margin({ left: 26, right: 26, bottom: 26 })
          .shadow({ radius: 28, color: $r('app.color.shadow_card'), offsetX: 0, offsetY: 12 })

          Row() {
            Text(this.selectedFilter === '全部' ? '最近文件' : `${this.selectedFilter} · 筛选结果`)
              .fontSize(20)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text_primary'))
            Blank()
            Text(`${this.visibleFiles().length} 项`)
              .fontSize(13)
              .fontColor($r('app.color.text_caption'))
          }
          .width('100%')
          .padding({ left: 22, right: 22, bottom: 12 })

          Row({ space: 8 }) {
            Text('🔍')
              .fontSize(14)
              .fontColor($r('app.color.text_disabled'))
            TextInput({ text: this.query, placeholder: '搜索文件名或标签' })
              .layoutWeight(1)
              .height(36)
              .fontSize(14)
              .fontColor($r('app.color.text_primary'))
              .placeholderColor($r('app.color.text_disabled'))
              .placeholderFont({ size: 14 })
              .backgroundColor(Color.Transparent)
              .onChange((value: string) => {
                this.query = value;
              })
            if (this.query.length > 0) {
              Text('×')
                .fontSize(16)
                .fontColor($r('app.color.text_disabled'))
                .width(20)
                .height(20)
                .textAlign(TextAlign.Center)
                .onClick(() => {
                  this.query = '';
                })
            }
          }
          .width('100%')
          .height(44)
          .padding({ left: 14, right: 12 })
          .backgroundColor($r('app.color.tint_gray'))
          .borderRadius(16)
          .margin({ left: 22, right: 22, bottom: 14 })

          Column({ space: 10 }) {
            ForEach(this.visibleFiles(), (file: FileItem) => {
              Row() {
                Row() {
                  Text(file.icon)
                    .fontSize(22)
                    .fontColor($r('app.color.accent_blue'))
                }
                .width(48)
                .height(48)
                .justifyContent(FlexAlign.Center)
                .backgroundColor(file.color)
                .borderRadius(15)
                Column() {
                  Text(file.name)
                    .fontSize(15)
                    .fontWeight(FontWeight.Medium)
                    .fontColor($r('app.color.text_primary'))
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                  Row({ space: 7 }) {
                    Text(file.kind + ' · ' + file.size)
                      .fontSize(12)
                      .fontColor($r('app.color.text_caption'))
                    Text(file.tag)
                      .fontSize(11)
                      .fontColor($r('app.color.accent_blue'))
                      .padding({ left: 7, right: 7, top: 3, bottom: 3 })
                      .backgroundColor($r('app.color.tint_gray'))
                      .borderRadius(7)
                  }
                  .margin({ top: 5 })
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)
                .margin({ left: 12, right: 7 })
                Column() {
                  Text(file.updated)
                    .fontSize(10)
                    .fontColor($r('app.color.text_disabled'))
                }
                .width(54)
                .alignItems(HorizontalAlign.End)
                .alignSelf(ItemAlign.Start)
              }
              .width('100%')
              .padding({ left: 14, right: 14, top: 12, bottom: 12 })
              .backgroundColor($r('app.color.card_bg'))
              .borderRadius(18)
              .shadow({ radius: 8, color: $r('app.color.shadow_card'), offsetX: 0, offsetY: 2 })
              .scale({
                x: this.pressedFileId === file.id ? 0.985 : 1,
                y: this.pressedFileId === file.id ? 0.985 : 1
              })
              .animation({ curve: curves.springMotion(0.24, 1.0, 0.01) })
              .onTouch((event: TouchEvent) => {
                if (event.type === TouchType.Down) {
                  this.pressedFileId = file.id;
                } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
                  this.pressedFileId = 0;
                }
              })
              .gesture(
                GestureGroup(GestureMode.Exclusive,
                  LongPressGesture({ duration: 420, repeat: false })
                    .onAction(() => {
                      this.pressedFileId = 0;
                      this.presentTagEditor(file.id);
                    }),
                  TapGesture()
                    .onAction(() => {
                      this.pressedFileId = 0;
                      this.handleFileTap(file);
                    })
                )
              )
            }, (file: FileItem) => `${this.fileListRevision}_${file.id}_${file.tag}_${file.updated}_${file.manualTag}`)
          }
          .width('100%')
          .padding({ left: 20, right: 20, bottom: 108 })

          if (this.visibleFiles().length === 0) {
            Column() {
              Text(this.files.length === 0 ? '还没有导入真实文件' : '没有找到匹配文件')
                .fontSize(16)
                .fontColor($r('app.color.text_body'))
              Text(this.files.length === 0 ? '点击底部“添加”，从系统文件中选择' : '试试其他关键词或分类')
                .fontSize(13)
                .fontColor($r('app.color.text_disabled'))
                .margin({ top: 7 })
            }
            .width('100%')
            .padding({ top: 35, bottom: 120 })
          }
        }
        .width('100%')
      }
      .width('100%')
      .height('100%')
      .backgroundColor($r('app.color.page_bg'))
      .scrollBar(BarState.Off)
      .opacity(this.pageOpacity)
      .translate({ x: 0, y: this.pageOffset })

      if (this.selectedTab === '分类') {
        Scroll() {
          Column() {
            Row() {
              Column() {
                Text('分类')
                  .fontSize(30)
                  .fontWeight(FontWeight.Bold)
                  .fontColor($r('app.color.text_primary'))
                Text('按标签找到你要的文件')
                  .fontSize(14)
                  .fontColor($r('app.color.text_caption'))
                  .margin({ top: 5 })
              }
              .alignItems(HorizontalAlign.Start)
              Blank()
              Text(`${this.files.length} 项`)
                .fontSize(13)
                .fontColor($r('app.color.text_caption'))
            }
            .width('100%')
            .padding({ left: 22, right: 22, top: 23, bottom: 22 })
            Text('我的标签')
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text_primary'))
              .alignSelf(ItemAlign.Start)
              .margin({ left: 22, bottom: 12 })
            Column({ space: 10 }) {
              ForEach(this.categories, (category: CategoryItem) => {
                this.categoryCard(category.name, category.subtitle, category.color, category.icon)
              }, (category: CategoryItem) => category.name)
            }
            .width('100%')
            .padding({ left: 20, right: 20 })
            Row() {
              Text('自定义分类')
                .fontSize(15)
                .fontColor($r('app.color.accent_blue'))
              Blank()
              Text('+')
                .fontSize(23)
                .fontColor($r('app.color.accent_blue'))
                .width(32)
                .height(32)
                .textAlign(TextAlign.Center)
                .backgroundColor('#E9F0FF')
                .borderRadius(16)
            }
            .width('100%')
            .padding({ left: 16, right: 16, top: 14, bottom: 14 })
          .backgroundColor($r('app.color.card_bg'))
          .borderRadius(18)
          .margin({ left: 20, right: 20, top: 14 })
          .shadow({ radius: 8, color: $r('app.color.shadow_card'), offsetX: 0, offsetY: 2 })
            .onClick(() => {
              this.newCategoryName = '';
              this.newCategoryTitleKeywords = '';
              this.newCategoryFormats = '';
              this.showCategoryRuleOptions = false;
              this.showCategoryEditor = true;
            })
            Text('点击标签即可回到收纳箱查看结果')
              .fontSize(12)
              .fontColor($r('app.color.text_disabled'))
              .margin({ top: 18 })
          }
          .width('100%')
          .padding({ bottom: 118 })
        }
        .width('100%')
        .height('100%')
        .backgroundColor($r('app.color.page_bg'))
        .scrollBar(BarState.Off)
        .opacity(this.pageOpacity)
        .translate({ x: 0, y: this.pageOffset })
      }

      if (this.selectedTab === '设置') {
        Column() {
          Row() {
            Column() {
              Text('设置')
                .fontSize(30)
                .fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.text_primary'))
              Text('让收纳方式更贴合你的习惯')
                .fontSize(14)
                .fontColor($r('app.color.text_caption'))
                .margin({ top: 5 })
            }
            .alignItems(HorizontalAlign.Start)
          }
          .width('100%')
          .padding({ left: 22, right: 22, top: 23, bottom: 23 })
          Text('整理偏好')
            .fontSize(13)
            .fontColor($r('app.color.text_caption'))
            .alignSelf(ItemAlign.Start)
            .margin({ left: 22, bottom: 9 })
          Row() {
            Column() {
              Text('立即整理')
                .fontSize(16)
                .fontColor($r('app.color.text_primary'))
              Text('按当前规则整理待整理文件')
                .fontSize(12)
                .fontColor($r('app.color.text_caption'))
                .margin({ top: 4 })
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)
            Button('运行')
              .fontSize(12)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.accent_green'))
              .backgroundColor('#E5F4EC')
              .borderRadius(12)
              .onClick(() => {
                this.runAutoOrganize();
              })
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 15, bottom: 15 })
          .backgroundColor($r('app.color.card_bg'))
          .borderRadius(18)
          .shadow({ radius: 8, color: $r('app.color.shadow_card'), offsetX: 0, offsetY: 2 })
          Text('文件范围')
            .fontSize(13)
            .fontColor($r('app.color.text_caption'))
            .alignSelf(ItemAlign.Start)
            .margin({ left: 22, top: 23, bottom: 9 })
          Row() {
            Column() {
              Text('已选择的文件')
                .fontSize(16)
                .fontColor($r('app.color.text_primary'))
              Text('只整理你授权过的文件，更安全')
                .fontSize(12)
                .fontColor($r('app.color.text_caption'))
                .margin({ top: 4 })
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)
            Text('›')
              .fontSize(22)
              .fontColor($r('app.color.text_disabled'))
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 15, bottom: 15 })
          .backgroundColor($r('app.color.card_bg'))
          .borderRadius(18)
          .shadow({ radius: 8, color: $r('app.color.shadow_card'), offsetX: 0, offsetY: 2 })
          Text('关于收纳箱')
            .fontSize(13)
            .fontColor($r('app.color.text_caption'))
            .alignSelf(ItemAlign.Start)
            .margin({ left: 22, top: 23, bottom: 9 })
          Row() {
            Text('版本 1.0.0 · ArkUI-X')
              .fontSize(15)
              .fontColor($r('app.color.text_body'))
            Blank()
            Text('›')
              .fontSize(22)
              .fontColor($r('app.color.text_disabled'))
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 16, bottom: 16 })
          .backgroundColor($r('app.color.card_bg'))
          .borderRadius(18)
          .shadow({ radius: 8, color: $r('app.color.shadow_card'), offsetX: 0, offsetY: 2 })
        }
        .width('100%')
        .height('100%')
        .padding({ bottom: 76 })
        .backgroundColor($r('app.color.page_bg'))
        .opacity(this.pageOpacity)
        .translate({ x: 0, y: this.pageOffset })
      }

      if (this.selectedTab === '智能') {
        Scroll() {
          Column() {
          Row() {
            Column() {
              Text('智能')
                .fontSize(30)
                .fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.text_primary'))
              Text('把重复整理交给规则')
                .fontSize(14)
                .fontColor($r('app.color.text_caption'))
                .margin({ top: 5 })
            }
            .alignItems(HorizontalAlign.Start)
            Blank()
            Text('✧')
              .fontSize(24)
              .fontColor($r('app.color.accent_blue'))
              .width(42)
              .height(42)
              .textAlign(TextAlign.Center)
              .backgroundColor('#E9F0FF')
              .borderRadius(21)
          }
          .width('100%')
          .padding({ left: 22, right: 22, top: 23, bottom: 20 })
          Row() {
            Column() {
              Text('运行智能整理')
                .fontSize(18)
                .fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.text_primary'))
              Text(this.files.length === 0 ? '导入文件后可按规则自动归类' : `按当前规则整理 ${this.files.length} 个文件`)
                .fontSize(13)
                .fontColor($r('app.color.text_caption'))
                .margin({ top: 7 })
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)
            Button('立即整理')
              .fontSize(12)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.accent_green'))
              .backgroundColor('#E5F4EC')
              .borderRadius(12)
              .onClick(() => {
                this.runAutoOrganize();
              })
          }
          .width('100%')
          .padding({ left: 18, right: 18, top: 18, bottom: 18 })
          .backgroundColor($r('app.color.tint_blue_strong'))
          .borderRadius(22)
          .margin({ left: 20, right: 20, bottom: 22 })
          .shadow({ radius: 8, color: $r('app.color.shadow_card'), offsetX: 0, offsetY: 2 })
          Row({ space: 8 }) {
            Button('AI 整理')
              .fontSize(12)
              .fontColor(Color.White)
              .backgroundColor($r('app.color.accent_primary'))
              .borderRadius(12)
              .onClick(() => router.pushUrl({ url: 'pages/AIOrganizePage' }))
            Button('文件问答')
              .fontSize(12)
              .fontColor($r('app.color.accent_blue'))
              .backgroundColor('#E9F0FF')
              .borderRadius(12)
              .onClick(() => router.pushUrl({ url: 'pages/ChatPage' }))
            Button('LLM 配置')
              .fontSize(12)
              .fontColor($r('app.color.accent_blue'))
              .backgroundColor('#E9F0FF')
              .borderRadius(12)
              .onClick(() => router.pushUrl({ url: 'pages/LLMConfigPage' }))
          }
          .width('100%')
          .margin({ left: 20, right: 20, bottom: 18 })
          Text(this.llmConfigured ? 'LLM 已配置，可使用 AI 服务' : 'LLM 未配置：点击“LLM 配置”开始')
            .fontSize(12)
            .fontColor(this.llmConfigured ? $r('app.color.accent_green') : $r('app.color.text_caption'))
            .alignSelf(ItemAlign.Start)
            .margin({ left: 22, bottom: 18 })
          Text('你的使用方式')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
            .alignSelf(ItemAlign.Start)
            .margin({ left: 22, bottom: 11 })
          Row({ space: 8 }) {
            Button('学生')
              .fontSize(13)
              .fontColor(this.profileType === '学生' ? Color.White : $r('app.color.text_body'))
              .height(36)
              .backgroundColor(this.profileType === '学生' ? $r('app.color.accent_primary') : $r('app.color.tint_gray'))
              .borderRadius(15)
              .onClick(() => { this.requestProfileChange('学生'); })
            Button('摄影师')
              .fontSize(13)
              .fontColor(this.profileType === '摄影师' ? Color.White : $r('app.color.text_body'))
              .height(36)
              .backgroundColor(this.profileType === '摄影师' ? $r('app.color.accent_primary') : $r('app.color.tint_gray'))
              .borderRadius(15)
              .onClick(() => { this.requestProfileChange('摄影师'); })
            Button('程序员')
              .fontSize(13)
              .fontColor(this.profileType === '程序员' ? Color.White : $r('app.color.text_body'))
              .height(36)
              .backgroundColor(this.profileType === '程序员' ? $r('app.color.accent_primary') : $r('app.color.tint_gray'))
              .borderRadius(15)
              .onClick(() => { this.requestProfileChange('程序员'); })
            Button('通用')
              .fontSize(13)
              .fontColor(this.profileType === '通用' ? Color.White : $r('app.color.text_body'))
              .height(36)
              .backgroundColor(this.profileType === '通用' ? $r('app.color.accent_primary') : $r('app.color.tint_gray'))
              .borderRadius(15)
              .onClick(() => { this.requestProfileChange('通用'); })
          }
          .width('100%')
          .padding({ left: 20, right: 20 })
          Text(this.profileType === '未设置' ? '选择后会生成更适合你的默认规则' : `已按${this.profileType}场景生成建议`)
            .fontSize(12)
            .fontColor($r('app.color.text_caption'))
            .alignSelf(ItemAlign.Start)
            .margin({ left: 22, top: 9, bottom: 22 })
          Text(this.profileType === '学生' ? '建议依据：学科名称、作业/笔记关键词、课程文件夹' : this.profileType === '摄影师' ? '建议依据：拍摄日期、项目名、RAW/JPEG/视频类型' : this.profileType === '程序员' ? '建议依据：项目目录、语言扩展名、README 与构建产物' : '建议依据：文件名、类型、大小和最近使用时间')
            .fontSize(12)
            .fontColor($r('app.color.accent_blue'))
            .alignSelf(ItemAlign.Start)
            .margin({ left: 22, top: -13, bottom: 20 })
          Row() {
            Text('整理规则')
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text_primary'))
            Blank()
            Button('+ 新建规则')
              .fontSize(12)
              .fontColor($r('app.color.accent_blue'))
              .backgroundColor('#E9F0FF')
              .borderRadius(13)
              .onClick(() => { this.startNewRule(); })
          }
          .width('100%')
          .padding({ left: 22, right: 20, bottom: 11 })
          this.ruleSection('用户规则', this.customRules())
          this.ruleSection('默认规则', this.defaultRules())
          Blank()
            .height(95)
          }
          .width('100%')
        }
        .width('100%')
        .height('100%')
        .backgroundColor($r('app.color.page_bg'))
        .opacity(this.pageOpacity)
        .translate({ x: 0, y: this.pageOffset })
      }

      Row() {
        Column() {
          Text('▦').fontSize(23).fontColor(this.selectedTab === '收纳箱' ? $r('app.color.text_primary') : $r('app.color.text_disabled')).height(29).textAlign(TextAlign.Center)
          Text('收纳箱').fontSize(11).fontColor(this.selectedTab === '收纳箱' ? $r('app.color.text_primary') : $r('app.color.text_disabled')).margin({ top: 0 })
        }
        .layoutWeight(1)
        .height(60)
        .justifyContent(FlexAlign.Center)
        .onClick(() => { this.switchTab('收纳箱'); })
        Column() {
          Text('◇').fontSize(23).fontColor(this.selectedTab === '分类' ? $r('app.color.text_primary') : $r('app.color.text_disabled')).height(29).textAlign(TextAlign.Center)
          Text('分类').fontSize(11).fontColor(this.selectedTab === '分类' ? $r('app.color.text_primary') : $r('app.color.text_disabled')).margin({ top: 0 })
        }
        .layoutWeight(1)
        .height(60)
        .justifyContent(FlexAlign.Center)
        .onClick(() => { this.switchTab('分类'); })
        Column() {
          Button('+')
            .fontSize(24)
            .fontWeight(FontWeight.Lighter)
            .fontColor(Color.White)
            .width(44)
            .height(44)
            .borderRadius(22)
            .backgroundColor($r('app.color.accent_primary'))
            .onClick(() => { this.showQuickAdd = true; })
          Text('添加')
            .fontSize(11)
            .fontColor($r('app.color.text_caption'))
            .margin({ top: 2 })
        }
        .layoutWeight(1)
        .height(60)
        .justifyContent(FlexAlign.Center)
        Column() {
          Text('✧')
            .fontSize(23)
            .fontColor(this.selectedTab === '智能' ? $r('app.color.text_primary') : $r('app.color.text_disabled'))
            .height(29)
            .textAlign(TextAlign.Center)
          Text('智能')
            .fontSize(11)
            .fontColor(this.selectedTab === '智能' ? $r('app.color.text_primary') : $r('app.color.text_disabled'))
            .margin({ top: 0 })
        }
        .layoutWeight(1)
        .height(60)
        .justifyContent(FlexAlign.Center)
        .onClick(() => { this.switchTab('智能'); })
        Column() {
          Text('⚙').fontSize(21).fontColor(this.selectedTab === '设置' ? $r('app.color.text_primary') : $r('app.color.text_disabled')).height(29).textAlign(TextAlign.Center)
          Text('设置').fontSize(11).fontColor(this.selectedTab === '设置' ? $r('app.color.text_primary') : $r('app.color.text_disabled')).margin({ top: 0 })
        }
        .layoutWeight(1)
        .height(60)
        .justifyContent(FlexAlign.Center)
        .onClick(() => { this.switchTab('设置'); })
      }
      .height(72)
      .width('100%')
      .padding({ left: 16, right: 16, bottom: 7 })
      .backgroundColor($r('app.color.blur_bg_bar'))
      .backgroundBlurStyle(BlurStyle.Thin)
      .borderRadius({ topLeft: 26, topRight: 26 })

      if (this.showProfileChangeWarning) {
        Column() {
          Column() {
            Text('切换使用方式？')
              .fontSize(21)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text_primary'))
              .alignSelf(ItemAlign.Start)
            Text(`切换到「${this.pendingProfileType}」会替换默认分类和默认整理规则，部分已归类文件可能会按新规则重新整理，原有归类可能被打散。自定义分类和用户规则会保留。`)
              .fontSize(13)
              .fontColor($r('app.color.text_caption'))
              .lineHeight(20)
              .margin({ top: 12, bottom: 18 })
            Row({ space: 10 }) {
              Button('取消')
                .height(44)
                .layoutWeight(1)
                .fontSize(15)
                .fontColor($r('app.color.text_body'))
                .backgroundColor($r('app.color.tint_gray'))
                .borderRadius(14)
                .onClick(() => { this.cancelProfileChange(); })
              Button('继续切换')
                .height(44)
                .layoutWeight(1)
                .fontSize(15)
                .fontColor(Color.White)
                .backgroundColor($r('app.color.accent_primary'))
                .borderRadius(14)
                .onClick(() => { this.confirmProfileChange(); })
            }
            .width('100%')
          }
          .width('86%')
          .padding({ left: 20, right: 20, top: 21, bottom: 18 })
          .backgroundColor($r('app.color.card_bg'))
          .borderRadius(22)
          .shadow({ radius: 16, color: $r('app.color.shadow_card'), offsetX: 0, offsetY: 6 })
          .transition(TransitionEffect.scale({ x: 0.92, y: 0.92 }).animation({ duration: 250, curve: Curve.EaseOut }))
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .backgroundColor($r('app.color.mask'))
        .transition(TransitionEffect.OPACITY.animation({ duration: 250 }))
      }

      if (this.showRuleDeleteConfirm) {
        Column() {
          Column() {
            Text('删除整理规则？')
              .fontSize(21)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text_primary'))
              .alignSelf(ItemAlign.Start)
            Text(`将删除「${this.ruleName}」这条规则。删除后不会删除分类和文件，但之后自动整理不会再使用这条规则。`)
              .fontSize(13)
              .fontColor($r('app.color.text_caption'))
              .lineHeight(20)
              .margin({ top: 12, bottom: 18 })
            Row({ space: 10 }) {
              Button('取消')
                .height(44)
                .layoutWeight(1)
                .fontSize(15)
                .fontColor($r('app.color.text_body'))
                .backgroundColor($r('app.color.tint_gray'))
                .borderRadius(14)
                .onClick(() => { this.cancelDeleteRule(); })
              Button('确认删除')
                .height(44)
                .layoutWeight(1)
                .fontSize(15)
                .fontColor(Color.White)
                .backgroundColor($r('app.color.accent_red'))
                .borderRadius(14)
                .onClick(() => { this.confirmDeleteRule(); })
            }
            .width('100%')
          }
          .width('86%')
          .padding({ left: 20, right: 20, top: 21, bottom: 18 })
          .backgroundColor($r('app.color.card_bg'))
          .borderRadius(22)
          .shadow({ radius: 16, color: $r('app.color.shadow_card'), offsetX: 0, offsetY: 6 })
          .transition(TransitionEffect.scale({ x: 0.92, y: 0.92 }).animation({ duration: 250, curve: Curve.EaseOut }))
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .backgroundColor($r('app.color.mask'))
        .transition(TransitionEffect.OPACITY.animation({ duration: 250 }))
      }

      if (this.showCategoryDeleteConfirm) {
        Column() {
          Column() {
            Text('删除标签？')
              .fontSize(21)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text_primary'))
              .alignSelf(ItemAlign.Start)
            Text(`将删除「${this.deletingCategoryName}」标签。该标签下的 ${this.categoryCount(this.deletingCategoryName)} 个文件会移入「待整理」，目标为该标签的整理规则也会一并移除。`)
              .fontSize(13)
              .fontColor($r('app.color.text_caption'))
              .lineHeight(20)
              .margin({ top: 12, bottom: 18 })
            Row({ space: 10 }) {
              Button('取消')
                .height(44)
                .layoutWeight(1)
                .fontSize(15)
                .fontColor($r('app.color.text_body'))
                .backgroundColor($r('app.color.tint_gray'))
                .borderRadius(14)
                .onClick(() => { this.cancelDeleteCategory(); })
              Button('确认删除')
                .height(44)
                .layoutWeight(1)
                .fontSize(15)
                .fontColor(Color.White)
                .backgroundColor($r('app.color.accent_red'))
                .borderRadius(14)
                .onClick(() => { this.confirmDeleteCategory(); })
            }
            .width('100%')
          }
          .width('86%')
          .padding({ left: 20, right: 20, top: 21, bottom: 18 })
          .backgroundColor($r('app.color.card_bg'))
          .borderRadius(22)
          .shadow({ radius: 16, color: $r('app.color.shadow_card'), offsetX: 0, offsetY: 6 })
          .transition(TransitionEffect.scale({ x: 0.92, y: 0.92 }).animation({ duration: 250, curve: Curve.EaseOut }))
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .backgroundColor($r('app.color.mask'))
        .transition(TransitionEffect.OPACITY.animation({ duration: 250 }))
      }

      if (this.showManualConfirm) {
        Column() {
          Column() {
            Row() {
              Column() {
                Text('人工确认')
                  .fontSize(21)
                  .fontWeight(FontWeight.Bold)
                  .fontColor($r('app.color.text_primary'))
                Text(`还有 ${this.pendingManualConfirmIds.length} 个文件规则无法判断`)
                  .fontSize(12)
                  .fontColor($r('app.color.text_caption'))
                  .margin({ top: 5 })
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)
              Text('×')
                .fontSize(24)
                .fontColor($r('app.color.text_caption'))
                .width(34)
                .height(34)
                .textAlign(TextAlign.Center)
                .onClick(() => { this.finishManualConfirmation(); })
            }
            .width('100%')
            Text('请选择合适分类；不确定的文件可以继续留在「待整理」，不会被自动覆盖。')
              .fontSize(13)
              .fontColor($r('app.color.text_caption'))
              .lineHeight(20)
              .margin({ top: 12, bottom: 14 })
              .alignSelf(ItemAlign.Start)
            Scroll() {
              Column({ space: 10 }) {
                ForEach(this.manualConfirmFiles(), (file: FileItem) => {
                  Column() {
                    Row() {
                      Text(file.icon)
                        .fontSize(15)
                        .fontColor($r('app.color.accent_amber'))
                        .width(30)
                        .height(30)
                        .textAlign(TextAlign.Center)
                        .backgroundColor(file.color)
                        .borderRadius(10)
                      Column() {
                        Text(file.name)
                          .fontSize(14)
                          .fontWeight(FontWeight.Medium)
                          .fontColor($r('app.color.text_primary'))
                          .maxLines(1)
                          .textOverflow({ overflow: TextOverflow.Ellipsis })
                        Text(`${file.kind} · ${file.parseStatus}`)
                          .fontSize(11)
                          .fontColor($r('app.color.text_caption'))
                          .maxLines(1)
                          .textOverflow({ overflow: TextOverflow.Ellipsis })
                          .margin({ top: 3 })
                      }
                      .alignItems(HorizontalAlign.Start)
                      .layoutWeight(1)
                      .margin({ left: 10 })
                    }
                    .width('100%')
                    Flex({ wrap: FlexWrap.Wrap }) {
                      ForEach(this.categories, (category: CategoryItem) => {
                        if (category.name !== '待整理') {
                          Text(category.name)
                            .fontSize(12)
                            .fontWeight(FontWeight.Medium)
                            .fontColor($r('app.color.text_body'))
                            .padding({ left: 12, right: 12, top: 7, bottom: 7 })
                            .backgroundColor(category.color)
                            .borderRadius(13)
                            .margin({ right: 8, bottom: 8 })
                            .onClick(() => { this.chooseManualConfirmTag(file.id, category.name); })
                        }
                      }, (category: CategoryItem) => category.name)
                      Text('保持待整理')
                        .fontSize(12)
                        .fontWeight(FontWeight.Medium)
                        .fontColor($r('app.color.accent_amber'))
                        .padding({ left: 12, right: 12, top: 7, bottom: 7 })
                        .backgroundColor('#FFF0DD')
                        .borderRadius(13)
                        .margin({ right: 8, bottom: 8 })
                        .onClick(() => { this.chooseManualConfirmTag(file.id, '待整理'); })
                    }
                    .width('100%')
                    .margin({ top: 12 })
                  }
                  .width('100%')
                  .padding({ left: 12, right: 12, top: 12, bottom: 8 })
                  .backgroundColor($r('app.color.tint_gray'))
                  .borderRadius(14)
                }, (file: FileItem) => `${file.id}-${file.tag}`)
              }
              .width('100%')
            }
            .width('100%')
            .height(300)
            Button('稍后处理')
              .width('100%')
              .height(44)
              .fontSize(15)
              .fontColor($r('app.color.text_body'))
              .backgroundColor($r('app.color.tint_gray'))
              .borderRadius(15)
              .margin({ top: 16 })
              .onClick(() => { this.finishManualConfirmation(); })
          }
          .width('88%')
          .padding({ left: 18, right: 18, top: 18, bottom: 18 })
          .backgroundColor($r('app.color.card_bg'))
          .borderRadius(22)
          .shadow({ radius: 16, color: $r('app.color.shadow_card'), offsetX: 0, offsetY: 6 })
          .transition(TransitionEffect.scale({ x: 0.92, y: 0.92 }).animation({ duration: 250, curve: Curve.EaseOut }))
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .backgroundColor($r('app.color.mask'))
        .transition(TransitionEffect.OPACITY.animation({ duration: 250 }))
      }

      if (this.showOrganizeSummary) {
        Column() {
          Column() {
            Row() {
              Column() {
                Text('整理完成')
                  .fontSize(21)
                  .fontWeight(FontWeight.Bold)
                  .fontColor($r('app.color.text_primary'))
                Text(`本次调整 ${this.lastOrganizeChangedCount} 个文件 · 已归类 ${this.lastOrganizedCount} 个`)
                  .fontSize(12)
                  .fontColor($r('app.color.text_caption'))
                  .margin({ top: 5 })
                if (this.lastManualConfirmedCount > 0) {
                  Text(`其中人工确认 ${this.lastManualConfirmedCount} 个`)
                    .fontSize(12)
                    .fontColor($r('app.color.accent_green'))
                    .margin({ top: 4 })
                }
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)
              Text('×')
                .fontSize(24)
                .fontColor($r('app.color.text_caption'))
                .width(34)
                .height(34)
                .textAlign(TextAlign.Center)
                .onClick(() => { this.showOrganizeSummary = false; })
            }
            .width('100%')
            Row() {
              Text('待整理')
                .fontSize(13)
                .fontColor($r('app.color.accent_amber'))
              Blank()
              Text(`${this.categoryCount('待整理')} 项`)
                .fontSize(13)
                .fontWeight(FontWeight.Medium)
                .fontColor($r('app.color.accent_amber'))
            }
            .width('100%')
            .padding({ left: 12, right: 12, top: 10, bottom: 10 })
            .backgroundColor('#FFF0DD')
            .borderRadius(13)
            .margin({ top: 16, bottom: 10 })
            Column({ space: 8 }) {
              ForEach(this.categories, (category: CategoryItem) => {
                if (category.name !== '待整理') {
                  Row() {
                    Text(category.icon)
                      .fontSize(15)
                      .fontColor($r('app.color.accent_blue'))
                      .width(28)
                      .height(28)
                      .textAlign(TextAlign.Center)
                      .backgroundColor(category.color)
                      .borderRadius(9)
                    Text(category.name)
                      .fontSize(13)
                      .fontColor($r('app.color.text_body'))
                      .margin({ left: 9 })
                    Blank()
                    Text(`${this.categoryCount(category.name)} 项`)
                      .fontSize(13)
                      .fontColor($r('app.color.text_caption'))
                  }
                  .width('100%')
                  .padding({ left: 10, right: 10, top: 8, bottom: 8 })
                  .backgroundColor($r('app.color.tint_gray'))
                  .borderRadius(12)
                }
              }, (category: CategoryItem) => category.name)
            }
            .width('100%')
            .margin({ bottom: 16 })
            Button('查看分类结果')
              .width('100%')
              .height(44)
              .fontSize(15)
              .fontColor(Color.White)
              .backgroundColor($r('app.color.accent_primary'))
              .borderRadius(15)
              .onClick(() => {
                this.showOrganizeSummary = false;
                this.switchTab('分类');
              })
          }
          .width('88%')
          .padding({ left: 18, right: 18, top: 18, bottom: 18 })
          .backgroundColor($r('app.color.card_bg'))
          .borderRadius(22)
          .shadow({ radius: 16, color: $r('app.color.shadow_card'), offsetX: 0, offsetY: 6 })
          .transition(TransitionEffect.scale({ x: 0.92, y: 0.92 }).animation({ duration: 250, curve: Curve.EaseOut }))
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .backgroundColor($r('app.color.mask'))
        .transition(TransitionEffect.OPACITY.animation({ duration: 250 }))
      }

      if (this.showFileAction) {
        Column() {
          Row() {
            Text('还没有归纳')
              .fontSize(20)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text_primary'))
            Blank()
            Text('×')
              .fontSize(23)
              .fontColor($r('app.color.text_caption'))
              .onClick(() => { this.showFileAction = false; })
          }
          .width('100%')
          Text(this.selectedFileName)
            .fontSize(15)
            .fontColor($r('app.color.text_body'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .margin({ top: 13, bottom: 18 })
          Text('你可以先归入分类，也可以直接打开文件')
            .fontSize(13)
            .fontColor($r('app.color.text_caption'))
            .alignSelf(ItemAlign.Start)
            .margin({ bottom: 15 })
          Row({ space: 10 }) {
            Button('归纳')
              .layoutWeight(1)
              .height(46)
              .fontSize(15)
              .fontColor(Color.White)
              .backgroundColor($r('app.color.accent_primary'))
              .borderRadius(15)
              .onClick(() => {
                this.presentTagEditor(this.selectedFileId);
              })
            Button('打开文件')
              .layoutWeight(1)
              .height(46)
              .fontSize(15)
              .fontColor($r('app.color.accent_blue'))
              .backgroundColor('#E9F0FF')
              .borderRadius(15)
              .onClick(() => {
                this.showFileAction = false;
                const target = this.files.find((file: FileItem) => file.id === this.selectedFileId);
                if (target !== undefined) {
                  this.openFile(target);
                }
              })
          }
          .width('100%')
        }
        .width('100%')
        .padding({ left: 22, right: 22, top: 20, bottom: 26 })
        .backgroundColor($r('app.color.blur_bg_sheet'))
        .backgroundBlurStyle(BlurStyle.Thin)
        .borderRadius({ topLeft: 26, topRight: 26 })
        .transition(TransitionEffect.OPACITY
          .combine(TransitionEffect.translate({ y: 200 }))
          .animation({ duration: 300, curve: Curve.EaseOut }))
      }

      if (this.showCategoryEditor) {
        Column() {
          Row() {
            Text('新建分类')
              .fontSize(20)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text_primary'))
            Blank()
            Text('×')
              .fontSize(23)
              .fontColor($r('app.color.text_caption'))
              .onClick(() => { this.showCategoryEditor = false; })
          }
          .width('100%')
          TextInput({ text: this.newCategoryName, placeholder: '分类名称，例如：课程资料' })
            .width('100%')
            .height(48)
            .margin({ top: 17, bottom: 15 })
            .onChange((value: string) => { this.newCategoryName = value; })
          Text('选择图标')
            .fontSize(13)
            .fontColor($r('app.color.text_caption'))
            .alignSelf(ItemAlign.Start)
          Row({ space: 12 }) {
            Text('▤').fontSize(20).fontColor($r('app.color.accent_blue')).width(36).height(36).textAlign(TextAlign.Center).backgroundColor(this.newCategoryIcon === '▤' ? '#E9F0FF' : $r('app.color.tint_gray')).borderRadius(12).onClick(() => { this.newCategoryIcon = '▤'; })
            Text('✦').fontSize(20).fontColor($r('app.color.accent_purple')).width(36).height(36).textAlign(TextAlign.Center).backgroundColor(this.newCategoryIcon === '✦' ? '#F3E9FF' : $r('app.color.tint_gray')).borderRadius(12).onClick(() => { this.newCategoryIcon = '✦'; })
            Text('◇').fontSize(20).fontColor($r('app.color.accent_green')).width(36).height(36).textAlign(TextAlign.Center).backgroundColor(this.newCategoryIcon === '◇' ? '#E5F7EF' : $r('app.color.tint_gray')).borderRadius(12).onClick(() => { this.newCategoryIcon = '◇'; })
            Text('◉').fontSize(20).fontColor($r('app.color.accent_amber')).width(36).height(36).textAlign(TextAlign.Center).backgroundColor(this.newCategoryIcon === '◉' ? '#FFF0DD' : $r('app.color.tint_gray')).borderRadius(12).onClick(() => { this.newCategoryIcon = '◉'; })
          }
          .width('100%')
          .margin({ top: 9, bottom: 14 })
          Text('选择颜色')
            .fontSize(13)
            .fontColor($r('app.color.text_caption'))
            .alignSelf(ItemAlign.Start)
          Row({ space: 14 }) {
            Text(this.newCategoryColor === '#E9F0FF' ? '✓' : '')
              .fontSize(15)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.accent_blue'))
              .width(36)
              .height(36)
              .textAlign(TextAlign.Center)
              .backgroundColor('#E9F0FF')
              .borderRadius(12)
              .border({ width: this.newCategoryColor === '#E9F0FF' ? 2 : 0, color: $r('app.color.accent_blue') })
              .onClick(() => { this.newCategoryColor = '#E9F0FF'; })
            Text(this.newCategoryColor === '#F3E9FF' ? '✓' : '')
              .fontSize(15)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.accent_purple'))
              .width(36)
              .height(36)
              .textAlign(TextAlign.Center)
              .backgroundColor('#F3E9FF')
              .borderRadius(12)
              .border({ width: this.newCategoryColor === '#F3E9FF' ? 2 : 0, color: $r('app.color.accent_purple') })
              .onClick(() => { this.newCategoryColor = '#F3E9FF'; })
            Text(this.newCategoryColor === '#E5F7EF' ? '✓' : '')
              .fontSize(15)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.accent_green'))
              .width(36)
              .height(36)
              .textAlign(TextAlign.Center)
              .backgroundColor('#E5F7EF')
              .borderRadius(12)
              .border({ width: this.newCategoryColor === '#E5F7EF' ? 2 : 0, color: $r('app.color.accent_green') })
              .onClick(() => { this.newCategoryColor = '#E5F7EF'; })
            Text(this.newCategoryColor === '#FFF0DD' ? '✓' : '')
              .fontSize(15)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.accent_amber'))
              .width(36)
              .height(36)
              .textAlign(TextAlign.Center)
              .backgroundColor('#FFF0DD')
              .borderRadius(12)
              .border({ width: this.newCategoryColor === '#FFF0DD' ? 2 : 0, color: $r('app.color.accent_amber') })
              .onClick(() => { this.newCategoryColor = '#FFF0DD'; })
            Text(this.newCategoryColor === '#E7F5F8' ? '✓' : '')
              .fontSize(15)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.accent_cyan'))
              .width(36)
              .height(36)
              .textAlign(TextAlign.Center)
              .backgroundColor('#E7F5F8')
              .borderRadius(12)
              .border({ width: this.newCategoryColor === '#E7F5F8' ? 2 : 0, color: $r('app.color.accent_cyan') })
              .onClick(() => { this.newCategoryColor = '#E7F5F8'; })
          }
          .width('100%')
          .margin({ top: 8, bottom: 17 })
          Row() {
            Text('筛选条件')
              .fontSize(13)
              .fontColor($r('app.color.text_body'))
            Blank()
            Text(this.showCategoryRuleOptions ? '收起' : '展开')
              .fontSize(12)
              .fontColor($r('app.color.accent_blue'))
              .padding({ left: 10, right: 10, top: 6, bottom: 6 })
              .backgroundColor('#E9F0FF')
              .borderRadius(12)
          }
          .width('100%')
          .padding({ left: 12, right: 12, top: 11, bottom: 11 })
          .backgroundColor($r('app.color.tint_gray'))
          .borderRadius(14)
          .margin({ bottom: this.showCategoryRuleOptions ? 9 : 17 })
          .onClick(() => { this.showCategoryRuleOptions = !this.showCategoryRuleOptions; })
          if (this.showCategoryRuleOptions) {
            Column() {
              TextInput({ text: this.newCategoryTitleKeywords, placeholder: '标题关键词：语文,试卷,笔记' })
                .width('100%')
                .height(42)
                .onChange((value: string) => { this.newCategoryTitleKeywords = value; })
              TextInput({ text: this.newCategoryFormats, placeholder: '文件格式：pdf,docx,pptx（不用写点号）' })
                .width('100%')
                .height(42)
                .margin({ top: 8 })
                .onChange((value: string) => { this.newCategoryFormats = value; })
              Text('保存后会同步加入“智能”的整理规则，自定义规则不会随使用方式切换而改变')
                .fontSize(10)
                .fontColor($r('app.color.text_caption'))
                .alignSelf(ItemAlign.Start)
                .margin({ top: 6 })
            }
            .width('100%')
            .margin({ bottom: 17 })
          }
          Button('保存分类')
            .width('100%')
            .height(46)
            .fontSize(15)
            .fontColor(Color.White)
            .backgroundColor($r('app.color.accent_primary'))
            .borderRadius(15)
            .onClick(() => { this.addCategory(); })
        }
        .width('100%')
        .padding({ left: 22, right: 22, top: 20, bottom: 25 })
        .backgroundColor($r('app.color.blur_bg_sheet'))
        .backgroundBlurStyle(BlurStyle.Thin)
        .borderRadius({ topLeft: 26, topRight: 26 })
        .transition(TransitionEffect.OPACITY
          .combine(TransitionEffect.translate({ y: 200 }))
          .animation({ duration: 300, curve: Curve.EaseOut }))
      }

      if (this.showRuleEditor) {
        Column() {
          Row() {
            Column() {
              Text(this.editingRuleId > 0 ? '编辑整理规则' : '新建整理规则')
                .fontSize(20)
                .fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.text_primary'))
              Text('填写的条件需同时满足，逗号分隔表示任一匹配')
                .fontSize(11)
                .fontColor($r('app.color.text_caption'))
                .margin({ top: 4 })
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)
            Text('×')
              .fontSize(23)
              .fontColor($r('app.color.text_caption'))
              .onClick(() => { this.showRuleEditor = false; })
          }
          .width('100%')
          TextInput({ text: this.ruleName, placeholder: '规则名称，例如：课程作业' })
            .width('100%')
            .height(44)
            .margin({ top: 14 })
            .onChange((value: string) => { this.ruleName = value; })
          TextInput({ text: this.ruleTitleKeywords, placeholder: '标题关键词：作业,实验报告' })
            .width('100%')
            .height(44)
            .margin({ top: 9 })
            .onChange((value: string) => { this.ruleTitleKeywords = value; })
          TextInput({ text: this.ruleFormats, placeholder: '文件格式：pdf,docx,pptx（不用写点号）' })
            .width('100%')
            .height(44)
            .margin({ top: 9 })
            .onChange((value: string) => { this.ruleFormats = value; })
          Text('整理到')
            .fontSize(12)
            .fontColor($r('app.color.text_caption'))
            .alignSelf(ItemAlign.Start)
            .margin({ top: 11, bottom: 7 })
          Scroll() {
            Row({ space: 8 }) {
              ForEach(this.categories, (category: CategoryItem) => {
                if (category.name !== '待整理') {
                  Text(category.name)
                    .fontSize(12)
                    .fontColor(this.ruleTargetTag === category.name ? Color.White : $r('app.color.text_body'))
                    .padding({ left: 12, right: 12, top: 8, bottom: 8 })
                    .backgroundColor(this.ruleTargetTag === category.name ? $r('app.color.accent_blue') : $r('app.color.tint_gray'))
                    .borderRadius(13)
                    .onClick(() => { this.ruleTargetTag = category.name; })
                }
              }, (category: CategoryItem) => category.name)
            }
          }
          .width('100%')
          .scrollable(ScrollDirection.Horizontal)
          .scrollBar(BarState.Off)
          Button('保存并立即整理')
            .width('100%')
            .height(46)
            .fontSize(15)
            .fontColor(Color.White)
            .backgroundColor($r('app.color.accent_primary'))
            .borderRadius(15)
            .margin({ top: 15 })
            .onClick(() => { this.saveCustomRule(); })
          if (this.editingRuleId > 0) {
            Button('删除规则')
              .width('100%')
              .height(42)
              .fontSize(14)
              .fontColor($r('app.color.accent_red'))
              .backgroundColor($r('app.color.tint_red'))
              .borderRadius(14)
              .margin({ top: 10 })
              .onClick(() => { this.requestDeleteRule(); })
          }
        }
        .width('100%')
        .padding({ left: 22, right: 22, top: 20, bottom: 23 })
        .backgroundColor($r('app.color.blur_bg_sheet'))
        .backgroundBlurStyle(BlurStyle.Thin)
        .borderRadius({ topLeft: 26, topRight: 26 })
        .transition(TransitionEffect.OPACITY
          .combine(TransitionEffect.translate({ y: 200 }))
          .animation({ duration: 300, curve: Curve.EaseOut }))
      }

      if (this.showQuickAdd) {
        Column() {
          Row() {
            Text('添加文件')
              .fontSize(20)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text_primary'))
            Blank()
            Text('×')
              .fontSize(23)
              .fontColor($r('app.color.text_caption'))
              .onClick(() => { this.showQuickAdd = false; })
          }
          .width('100%')
          Row() {
            Text('↗')
              .fontSize(22)
              .fontColor($r('app.color.accent_blue'))
              .width(34)
              .height(34)
              .textAlign(TextAlign.Center)
              .backgroundColor('#E9F0FF')
              .borderRadius(12)
            Column() {
              Text(this.selectedUris.length > 1 ? `${this.newFileName} 等 ${this.selectedUris.length} 个文件` : this.newFileName.length > 0 ? this.newFileName : '从设备批量选择文件')
                .fontSize(15)
                .fontColor($r('app.color.text_primary'))
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
              Text(this.selectedUris.length > 0 ? `已选择 ${this.selectedUris.length} 个，可再次选择继续添加` : '长按第一个文件进入多选，最多 100 个')
                .fontSize(12)
                .fontColor($r('app.color.text_caption'))
                .margin({ top: 4 })
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)
            .margin({ left: 10 })
            Text('›')
              .fontSize(24)
              .fontColor($r('app.color.text_caption'))
          }
          .width('100%')
          .height(66)
          .padding({ left: 12, right: 12 })
          .backgroundColor($r('app.color.tint_gray'))
          .borderRadius(16)
          .margin({ top: 18, bottom: 14 })
          .onClick(() => { this.selectFile(); })
          if (this.selectedUris.length > 0) {
            Button('+ 继续添加文件')
              .width('100%')
              .height(44)
              .fontSize(14)
              .fontColor($r('app.color.accent_blue'))
              .backgroundColor('#E9F0FF')
              .borderRadius(14)
              .margin({ bottom: 10 })
              .enabled(!this.isIndexing)
              .onClick(() => { this.selectFile(); })
          } else {
            Column() {
              Text('系统浏览不支持多选？')
                .fontSize(13)
                .fontWeight(FontWeight.Medium)
                .fontColor($r('app.color.text_body'))
              Text('可以每次选择一个，再用“继续添加文件”逐个累加；也可以从系统文件应用多选后分享至“拾序”。')
                .fontSize(11)
                .fontColor($r('app.color.text_caption'))
                .margin({ top: 5 })
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)
            .padding({ left: 12, right: 12, top: 10, bottom: 10 })
            .backgroundColor('#E9F0FF')
            .borderRadius(13)
            .margin({ bottom: 12 })
          }
          Button(this.isIndexing ? '正在导入…' : this.selectedUris.length > 0 ? `导入 ${this.selectedUris.length} 个文件` : '加入收纳箱')
            .width('100%')
            .height(48)
            .fontSize(16)
            .fontColor(Color.White)
            .backgroundColor($r('app.color.accent_primary'))
            .borderRadius(16)
            .enabled(!this.isIndexing)
            .onClick(() => { this.addFile(); })
        }
        .width('100%')
        .padding({ left: 22, right: 22, top: 20, bottom: 24 })
        .backgroundColor($r('app.color.blur_bg_sheet'))
        .backgroundBlurStyle(BlurStyle.Thin)
        .borderRadius({ topLeft: 26, topRight: 26 })
        .transition(TransitionEffect.OPACITY
          .combine(TransitionEffect.translate({ y: 200 }))
          .animation({ duration: 300, curve: Curve.EaseOut }))
      }

      if (this.showFileDetail) {
        Column() {
          Row() {
            Text('文件标签')
              .fontSize(20)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text_primary'))
            Blank()
            Text('×')
              .fontSize(23)
              .fontColor($r('app.color.text_caption'))
              .onClick(() => { this.showFileDetail = false; })
          }
          .width('100%')
          Text(this.selectedFileName)
            .fontSize(15)
            .fontColor($r('app.color.text_body'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .margin({ top: 14, bottom: 10 })
          Text('选择一个标签')
            .fontSize(13)
            .fontColor($r('app.color.text_caption'))
            .alignSelf(ItemAlign.Start)
          Column({ space: 9 }) {
            ForEach(this.categories, (category: CategoryItem) => {
              Row() {
                Text(category.icon)
                  .fontSize(16)
                  .fontColor($r('app.color.accent_blue'))
                  .width(26)
                  .height(26)
                  .textAlign(TextAlign.Center)
                  .backgroundColor(category.color)
                  .borderRadius(9)
                Text(category.name)
                  .fontSize(13)
                  .fontColor($r('app.color.text_body'))
                  .margin({ left: 9 })
              }
              .padding({ left: 12, right: 14, top: 8, bottom: 8 })
              .backgroundColor($r('app.color.tint_gray'))
              .borderRadius(14)
              .onClick(() => { this.retagSelected(category.name); })
            }, (category: CategoryItem) => category.name)
          }
          .width('100%')
          .margin({ top: 10 })
        }
        .width('100%')
        .padding({ left: 22, right: 22, top: 20, bottom: 26 })
        .backgroundColor($r('app.color.blur_bg_sheet'))
        .backgroundBlurStyle(BlurStyle.Thin)
        .borderRadius({ topLeft: 26, topRight: 26 })
        .transition(TransitionEffect.OPACITY
          .combine(TransitionEffect.translate({ y: 200 }))
          .animation({ duration: 300, curve: Curve.EaseOut }))
      }

      if (this.scanStatusType !== 'idle') {
        Row() {
          Row({ space: 8 }) {
            if (this.scanStatusType === 'progress') {
              LoadingProgress()
                .width(16)
                .height(16)
                .color($r('app.color.accent_blue'))
            } else {
              Text(this.scanStatusType === 'error' ? '!' : '✓')
                .fontSize(13)
                .fontWeight(FontWeight.Bold)
                .fontColor(this.scanStatusType === 'error' ? $r('app.color.accent_red') : $r('app.color.accent_green'))
                .width(16)
                .height(16)
                .textAlign(TextAlign.Center)
            }
            Text(this.scanStatus)
              .fontSize(13)
              .fontColor($r('app.color.text_body'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          .padding({ left: 16, right: 18, top: 10, bottom: 10 })
          .backgroundColor($r('app.color.card_bg'))
          .borderRadius(20)
          .shadow({ radius: 12, color: $r('app.color.shadow_card'), offsetX: 0, offsetY: 4 })
          .constraintSize({ maxWidth: '82%' })
        }
        .width('100%')
        .justifyContent(FlexAlign.Center)
        .position({ x: 0, y: 52 })
        .transition(TransitionEffect.OPACITY
          .combine(TransitionEffect.translate({ y: -20 }))
          .animation({ duration: 250, curve: Curve.EaseOut }))
      }
    }
    .width('100%')
    .height('100%')
  }
}
