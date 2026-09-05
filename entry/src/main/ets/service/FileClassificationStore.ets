import preferences from '@ohos.data.preferences'
import { common } from '@kit.AbilityKit'
import { FileItem, CategoryItem, SmartRule } from '../data/model/FileBoxTypes'
import { FileInfo } from '../data/model/FileInfo'
import { FileRepository } from '../data/repository/FileRepository'
import { applyCategory } from './ClassificationRules'

export function classificationFingerprint(value: string): string {
  let hash: number = 2166136261
  for (let i = 0; i < value.length; i++) hash = Math.imul(hash ^ value.charCodeAt(i), 16777619)
  return `${value.length}:${hash >>> 0}`
}

export function fileFingerprint(file: FileItem): string {
  return classificationFingerprint(JSON.stringify([file.uri, file.name, file.extension, file.contentText, file.tag, file.manualTag]))
}

/** File-box preferences are authoritative; the RDB category is a searchable projection. */
export class FileClassificationStore {
  private store: preferences.Preferences
  private repository: FileRepository = new FileRepository()
  constructor(context: common.Context) {
    this.store = preferences.getPreferencesSync(context, { name: 'file_box_data' })
  }
  files(): FileItem[] { return JSON.parse(this.store.getSync('files', '[]') as string) as FileItem[] }
  categories(): CategoryItem[] { return JSON.parse(this.store.getSync('categories', '[]') as string) as CategoryItem[] }
  rules(): SmartRule[] { return JSON.parse(this.store.getSync('rules', '[]') as string) as SmartRule[] }
  autoEnabled(): boolean { return this.store.getSync('autoOrganize', true) as boolean }
  rulesFingerprint(): string { return classificationFingerprint(JSON.stringify([this.rules(), this.categories()])) }

  async ensureIndexed(file: FileItem): Promise<number> {
    const existing = await this.repository.findByUri(file.uri)
    if (existing?.id !== undefined) {
      if (existing.category !== file.tag) await this.repository.updateCategory(existing.id, file.tag)
      return existing.id
    }
    const record = new FileInfo()
    record.uri = file.uri
    record.path = file.uri
    record.name = file.name
    record.type = file.kind
    record.contentSummary = file.contentText
    record.category = file.tag
    record.createdTime = file.importedAt
    record.modifiedTime = file.importedAt
    try { return await this.repository.insert(record) } catch (error) {
      const concurrent = await this.repository.findByUri(file.uri)
      if (concurrent?.id !== undefined) return concurrent.id
      throw new Error('文件索引写入失败，请重试')
    }
  }

  async classify(fileId: number, uri: string, categoryName: string, manual: boolean,
    expectedFile: string, expectedRules: string, ai: boolean = false): Promise<FileItem> {
    const files = this.files()
    const index = files.findIndex((file: FileItem) => file.id === fileId && file.uri === uri)
    if (index < 0) throw new Error('文件已移除，请刷新列表')
    const file = files[index]
    if (fileFingerprint(file) !== expectedFile || this.rulesFingerprint() !== expectedRules) {
      throw new Error('文件或规则已变化，请重新分析')
    }
    if (!manual && file.manualTag) throw new Error('文件已有人工分类，已保留')
    const category = this.categories().find((item: CategoryItem) => item.name === categoryName)
    if (category === undefined || category.name === '待整理') throw new Error('目标分类无效，请人工选择')
    files[index] = applyCategory(file, category, manual, ai)
    const raw = JSON.stringify(files)
    this.store.putSync('files', raw)
    await this.store.flush()
    if (typeof AppStorage !== 'undefined') {
      AppStorage.setOrCreate('fileBoxFiles', this.store.getSync('files', '[]') as string)
      AppStorage.setOrCreate('classificationRevision', (AppStorage.get<number>('classificationRevision') ?? 0) + 1)
    }
    // The authoritative write already succeeded. Reconcile this projection on the next run if RDB is busy.
    try { await this.ensureIndexed(files[index]) } catch (error) { console.warn('Category projection will be reconciled') }
    return files[index]
  }
}
