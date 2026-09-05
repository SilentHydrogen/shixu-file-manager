export interface CategoryItem {
  name: string;
  color: string;
  icon: string;
  subtitle: string;
}

export interface FileItem {
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
  aiCategory?: string;
}

export interface SmartRule {
  id: number;
  name: string;
  titleKeywords: string;
  contentKeywords: string;
  formats: string;
  targetTag: string;
  enabled: boolean;
  isDefault: boolean;
}

