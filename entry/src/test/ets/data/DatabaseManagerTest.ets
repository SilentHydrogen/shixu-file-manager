import { describe, it, expect } from '@ohos/hypium'
import { DatabaseManager } from '../../../main/ets/data/database/DatabaseManager'

export default function databaseManagerTest() {
  describe('DatabaseManager', () => {
    it('should initialize database successfully', 0, async () => {
      const dbManager = DatabaseManager.getInstance()
      const store = await dbManager.getStore()
      expect(store).assertInstanceOf("Object")
    })

    it('should create files table', 0, async () => {
      const dbManager = DatabaseManager.getInstance()
      const store = await dbManager.getStore()

      // 查询表是否存在
      const sql = "SELECT name FROM sqlite_master WHERE type='table' AND name='files'"
      const resultSet = await store.querySql(sql)
      const exists = resultSet.goToFirstRow()
      resultSet.close()

      expect(exists).assertTrue()
    })
  })
}
