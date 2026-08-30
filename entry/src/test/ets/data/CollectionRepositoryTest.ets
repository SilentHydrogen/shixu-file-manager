// entry/src/test/ets/data/CollectionRepositoryTest.ets

import { describe, it, expect, beforeAll, afterEach } from '@ohos/hypium'
import { CollectionRepository } from '../../../main/ets/data/repository/CollectionRepository'
import { Collection } from '../../../main/ets/data/model/Collection'
import { CollectionRule, ConditionType, OperatorType } from '../../../main/ets/data/model/CollectionRule'
import { DatabaseManager } from '../../../main/ets/data/database/DatabaseManager'
import common from '@ohos.app.ability.common'

export default function collectionRepositoryTest() {
  describe('CollectionRepository', () => {
    let repository: CollectionRepository

    beforeAll(async () => {
      await DatabaseManager.getInstance().init(getContext() as common.UIAbilityContext)
      repository = new CollectionRepository()
    })

    afterEach(async () => {
      const store = await DatabaseManager.getInstance().getStore()
      await store.executeSql('DELETE FROM collections')
    })

    it('should insert collection with rules', 0, async () => {
      const rule = new CollectionRule()
      rule.priority = 1
      rule.conditions = [
        {
          type: ConditionType.FILE_TYPE,
          operator: OperatorType.EQUALS,
          value: 'pdf'
        }
      ]

      const collection = new Collection()
      collection.name = 'PDF Documents'
      collection.icon = 'ic_pdf'
      collection.color = '#FF0000'
      collection.rules = [rule]

      const collectionId = await repository.insert(collection)
      expect(collectionId).assertLarger(0)
    })

    it('should find all collections', 0, async () => {
      const collection1 = new Collection()
      collection1.name = 'Collection 1'
      collection1.rules = []

      const collection2 = new Collection()
      collection2.name = 'Collection 2'
      collection2.rules = []

      await repository.insert(collection1)
      await repository.insert(collection2)

      const all = await repository.findAll()
      expect(all.length).assertEqual(2)
    })

    it('should find collection by id', 0, async () => {
      const collection = new Collection()
      collection.name = 'Test Collection'
      collection.description = 'Test description'
      collection.rules = []

      const collectionId = await repository.insert(collection)
      const found = await repository.findById(collectionId)

      expect(found).assertInstanceOf("Object")
      expect(found!.name).assertEqual('Test Collection')
      expect(found!.description).assertEqual('Test description')
    })

    it('should update collection', 0, async () => {
      const collection = new Collection()
      collection.name = 'Original Name'
      collection.rules = []

      const collectionId = await repository.insert(collection)

      const toUpdate = await repository.findById(collectionId)
      toUpdate!.name = 'Updated Name'
      toUpdate!.color = '#00FF00'
      await repository.update(toUpdate!)

      const updated = await repository.findById(collectionId)
      expect(updated!.name).assertEqual('Updated Name')
      expect(updated!.color).assertEqual('#00FF00')
    })

    it('should delete collection', 0, async () => {
      const collection = new Collection()
      collection.name = 'To Delete'
      collection.rules = []

      const collectionId = await repository.insert(collection)
      await repository.delete(collectionId)

      const deleted = await repository.findById(collectionId)
      expect(deleted).assertNull()
    })

    it('should find preset collections', 0, async () => {
      const preset = new Collection()
      preset.name = 'Preset Collection'
      preset.isPreset = true
      preset.rules = []

      const custom = new Collection()
      custom.name = 'Custom Collection'
      custom.isPreset = false
      custom.rules = []

      await repository.insert(preset)
      await repository.insert(custom)

      const presets = await repository.findPresets()
      expect(presets.length).assertEqual(1)
      expect(presets[0].name).assertEqual('Preset Collection')
    })
  })
}
