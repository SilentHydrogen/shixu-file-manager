// entry/src/test/ets/data/CollectionRepositoryTest.ets

import { describe, it, expect, beforeAll, afterEach } from '@ohos/hypium'
import { CollectionRepository } from '../../../main/ets/data/repository/CollectionRepository'
import { Collection } from '../../../main/ets/data/model/Collection'
import { CollectionRule, ConditionType, OperatorType } from '../../../main/ets/data/model/CollectionRule'
import { DatabaseManager } from '../../../main/ets/data/database/DatabaseManager'

export default function collectionRepositoryTest() {
  describe('CollectionRepository', () => {
    let repository: CollectionRepository

    beforeAll(async () => {
      await DatabaseManager.getInstance().init(getContext())
      repository = new CollectionRepository()
    })

    afterEach(async () => {
      const store = await DatabaseManager.getInstance().getStore()
      await store.executeSql('DELETE FROM collections')
    })

    it('should insert collection with rules', async () => {
      const rule: CollectionRule = new CollectionRule({
        priority: 1,
        conditions: [
          {
            type: ConditionType.FILE_TYPE,
            operator: OperatorType.EQUALS,
            value: 'pdf'
          }
        ]
      })

      const collection = new Collection({
        name: 'PDF Documents',
        icon: 'ic_pdf',
        color: '#FF0000',
        rules: [rule]
      })

      const collectionId = await repository.insert(collection)
      expect(collectionId).assertLarger(0)
    })

    it('should find all collections', async () => {
      const collection1 = new Collection({
        name: 'Collection 1',
        rules: []
      })

      const collection2 = new Collection({
        name: 'Collection 2',
        rules: []
      })

      await repository.insert(collection1)
      await repository.insert(collection2)

      const all = await repository.findAll()
      expect(all.length).assertEqual(2)
    })

    it('should find collection by id', async () => {
      const collection = new Collection({
        name: 'Test Collection',
        description: 'Test description',
        rules: []
      })

      const collectionId = await repository.insert(collection)
      const found = await repository.findById(collectionId)

      expect(found).assertNotNull()
      expect(found!.name).assertEqual('Test Collection')
      expect(found!.description).assertEqual('Test description')
    })

    it('should update collection', async () => {
      const collection = new Collection({
        name: 'Original Name',
        rules: []
      })

      const collectionId = await repository.insert(collection)

      const toUpdate = await repository.findById(collectionId)
      toUpdate!.name = 'Updated Name'
      toUpdate!.color = '#00FF00'
      await repository.update(toUpdate!)

      const updated = await repository.findById(collectionId)
      expect(updated!.name).assertEqual('Updated Name')
      expect(updated!.color).assertEqual('#00FF00')
    })

    it('should delete collection', async () => {
      const collection = new Collection({
        name: 'To Delete',
        rules: []
      })

      const collectionId = await repository.insert(collection)
      await repository.delete(collectionId)

      const deleted = await repository.findById(collectionId)
      expect(deleted).assertNull()
    })

    it('should find preset collections', async () => {
      const preset = new Collection({
        name: 'Preset Collection',
        isPreset: true,
        rules: []
      })

      const custom = new Collection({
        name: 'Custom Collection',
        isPreset: false,
        rules: []
      })

      await repository.insert(preset)
      await repository.insert(custom)

      const presets = await repository.findPresets()
      expect(presets.length).assertEqual(1)
      expect(presets[0].name).assertEqual('Preset Collection')
    })
  })
}
