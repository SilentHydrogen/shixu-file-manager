import fs from '@ohos.file.fs'

export interface WatchedDirectory {
  uri: string
  path: string
  recursive: boolean
  enabled: boolean
}

export class DirectoryMonitor {
  static readonly MAX_DIRECTORIES: number = 8
  static readonly MAX_FILES_PER_SCAN: number = 1000
  private directories: WatchedDirectory[] = []
  private watchers: Map<string, Object> = new Map()

  addDirectory(directory: WatchedDirectory): void {
    if (this.directories.some((item: WatchedDirectory) => item.uri === directory.uri)) return
    if (this.directories.length >= DirectoryMonitor.MAX_DIRECTORIES) throw new Error('At most 8 directories can be watched')
    this.directories.push(directory)
  }
  removeDirectory(uri: string): void {
    this.stopWatching(uri)
    this.directories = this.directories.filter((item: WatchedDirectory) => item.uri !== uri)
  }
  listDirectories(): WatchedDirectory[] { return [...this.directories] }
  async scan(path: string): Promise<string[]> {
    const result: string[] = []
    const walk = (current: string): void => {
      if (result.length >= DirectoryMonitor.MAX_FILES_PER_SCAN) return
      let entries: string[] = []
      try { entries = fs.listFileSync(current) } catch (error) { return }
      for (const entry of entries) {
        if (result.length >= DirectoryMonitor.MAX_FILES_PER_SCAN) break
        const child: string = `${current}/${entry}`
        try {
          const stat = fs.statSync(child)
          if (stat.isFile()) result.push(child)
          else if (stat.isDirectory()) walk(child)
        } catch (error) {
          // File may disappear while scan is running.
        }
      }
    }
    walk(path)
    return result
  }
  startWatching(directory: WatchedDirectory, callback: (path: string) => void): void {
    this.addDirectory(directory)
    try {
      const watcher = fs.createWatcher(directory.path, 4095, (event: fs.WatchEvent) => callback(event.fileName))
      watcher.start()
      this.watchers.set(directory.uri, watcher)
    } catch (error) { throw new Error('Directory watcher unavailable for granted URI') }
  }
  stopWatching(uri: string): void {
    const watcher = this.watchers.get(uri)
    if (watcher !== undefined) {
      try { (watcher as fs.Watcher).stop() } catch (error) {}
      this.watchers.delete(uri)
    }
  }
}
