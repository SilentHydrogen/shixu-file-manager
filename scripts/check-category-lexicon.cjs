const assert = require('node:assert/strict')
const fs = require('node:fs')
const path = require('node:path')
const Module = require('node:module')
const ts = require(process.env.ARKTS_TYPESCRIPT_PATH || path.join(process.env.DEVECO_CLI_CLT_PATH, 'hvigor/hvigor-ohos-plugin/node_modules/typescript'))
require.extensions['.ets'] = (module, filename) => module._compile(ts.transpileModule(fs.readFileSync(filename, 'utf8'), {
  compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020 }
}).outputText, filename)

const saved = Module._load
const stored = []
Module._load = function (id, ...args) {
  if (id === './model/EmbeddingModel') return { EmbeddingModel: class {} }
  if (id === '../data/repository/KeywordEmbeddingRepository') return { KeywordEmbeddingRepository: class {
    async list() { return [{ keyword: '会议', category: '工作', synonyms: ['会议', 'meeting'], embedding: [1, 0], updatedTime: 1 }] }
    async upsert() {}
  } }
  if (id === '../data/repository/CategoryLexiconRepository') return { CategoryLexiconRepository: class {
    async list() { return stored }
    async upsert(item) { stored.push(item) }
  } }
  return saved.call(this, id, ...args)
}

const model = {
  isAvailable: () => true,
  encode: async value => value.includes('研究') ? [0, 1] : [1, 0],
  encodeBatch: async values => values.map(() => [1, 0])
}

;(async () => {
  const { KeywordExpansionService } = require('../entry/src/main/ets/ai/KeywordExpansionService.ets')
  const service = new KeywordExpansionService(model)
  await service.initialize()
  const categories = [
    { name: '工作', subtitle: '会议与办公', color: 'a', icon: 'a' },
    { name: '研究', subtitle: '实验与电赛资料', color: 'b', icon: 'b' },
    { name: '待整理', subtitle: '', color: 'c', icon: 'c' }
  ]
  const rules = [{ id: 1, name: '电赛', titleKeywords: '电赛,实验', contentKeywords: '电路', formats: 'pdf', targetTag: '研究', enabled: true, isDefault: false }]
  const lexicons = await service.syncCategoryLexicons(categories, rules)
  assert.equal(lexicons.length, 3)
  assert.equal(lexicons.find(item => item.categoryName === '研究').source, 'user')
  assert.ok(lexicons.find(item => item.categoryName === '研究').seedKeywords.includes('电赛'))
  assert.ok(lexicons.every(item => item.expandedKeywords.length > 0))
  console.log('PASS: each preset and user category has an independent persisted lexicon with rule seeds')
})().catch(error => { console.error(error); process.exitCode = 1 })
