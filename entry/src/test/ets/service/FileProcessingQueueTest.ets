// entry/src/test/ets/service/FileProcessingQueueTest.ets

import { describe, it, expect, beforeEach } from '@ohos/hypium'
import { FileProcessingQueue } from '../../../main/ets/service/FileProcessingQueue'

export default function fileProcessingQueueTest() {
  describe('FileProcessingQueue', () => {
    let queue: FileProcessingQueue

    beforeEach(() => {
      queue = new FileProcessingQueue()
    })

    it('should enqueue and dequeue tasks', () => {
      queue.enqueue(1, 0)
      queue.enqueue(2, 0)

      expect(queue.size()).assertEqual(2)

      const task1 = queue.dequeue()
      expect(task1).assertNotNull()
      expect(task1!.fileId).assertEqual(1)

      expect(queue.size()).assertEqual(1)
    })

    it('should prioritize tasks by priority', () => {
      queue.enqueue(1, 0)
      queue.enqueue(2, 10)
      queue.enqueue(3, 5)

      const task1 = queue.dequeue()
      expect(task1!.fileId).assertEqual(2) // Highest priority

      const task2 = queue.dequeue()
      expect(task2!.fileId).assertEqual(3) // Medium priority

      const task3 = queue.dequeue()
      expect(task3!.fileId).assertEqual(1) // Lowest priority
    })

    it('should return null when dequeuing empty queue', () => {
      const task = queue.dequeue()
      expect(task).assertNull()
    })

    it('should clear all tasks', () => {
      queue.enqueue(1, 0)
      queue.enqueue(2, 0)
      queue.enqueue(3, 0)

      expect(queue.size()).assertEqual(3)

      queue.clear()
      expect(queue.size()).assertEqual(0)
    })

    it('should track processing status', () => {
      expect(queue.isProcessing()).assertFalse()

      queue.setProcessing(true)
      expect(queue.isProcessing()).assertTrue()

      queue.setProcessing(false)
      expect(queue.isProcessing()).assertFalse()
    })

    it('should store task metadata', () => {
      const beforeTime = Date.now()
      queue.enqueue(1, 5)
      const afterTime = Date.now()

      const task = queue.dequeue()
      expect(task).assertNotNull()
      expect(task!.fileId).assertEqual(1)
      expect(task!.priority).assertEqual(5)
      expect(task!.addedTime).assertLargerOrEqual(beforeTime)
      expect(task!.addedTime).assertLessOrEqual(afterTime)
    })
  })
}
