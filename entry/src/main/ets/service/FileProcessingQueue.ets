// entry/src/main/ets/service/FileProcessingQueue.ets

export interface QueueTask {
  fileId: number
  priority: number
  addedTime: number
}

export class FileProcessingQueue {
  private queue: QueueTask[] = []
  private processing: boolean = false

  /**
   * 添加任务到队列
   */
  enqueue(fileId: number, priority: number = 0): void {
    const task: QueueTask = {
      fileId,
      priority,
      addedTime: Date.now()
    }

    this.queue.push(task)
    this.queue.sort((a, b) => b.priority - a.priority)
  }

  /**
   * 从队列取出任务
   */
  dequeue(): QueueTask | null {
    return this.queue.shift() || null
  }

  /**
   * 获取队列长度
   */
  size(): number {
    return this.queue.length
  }

  /**
   * 清空队列
   */
  clear(): void {
    this.queue = []
  }

  /**
   * 检查是否正在处理
   */
  isProcessing(): boolean {
    return this.processing
  }

  /**
   * 设置处理状态
   */
  setProcessing(status: boolean): void {
    this.processing = status
  }
}
