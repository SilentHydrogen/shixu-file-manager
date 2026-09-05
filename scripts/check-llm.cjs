// Host regression checks execute the real ArkTS service code with a fake HTTP transport.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const Module = require('node:module');
const ts = require(process.env.ARKTS_TYPESCRIPT_PATH || (process.env.DEVECO_CLI_CLT_PATH ? path.join(process.env.DEVECO_CLI_CLT_PATH, 'hvigor/hvigor-ohos-plugin/node_modules/typescript') : 'typescript'));
require.extensions['.ets'] = (m, filename) => m._compile(ts.transpileModule(fs.readFileSync(filename, 'utf8'), { compilerOptions: { module: ts.ModuleKind.CommonJS, esModuleInterop: true, target: ts.ScriptTarget.ES2020 } }).outputText, filename);
let keyLookupError = 0;
let keyExists = false, generations = 0, isolateRag = false, categoryWrites = 0, processed = false;
let sent, destroyed = 0, reply = { responseCode: 200, result: JSON.stringify({ choices: [{ message: { content: 'ok' } }] }) };
const original = Module._load;
Module._load = function(id, ...rest) {
  if (isolateRag) {
    if (id === '../data/repository/FileRepository') return {FileRepository: class {
      async findById() { return {id:1, name:'fixture.txt', type:'txt', path:'/fixture', category:'工作'}; }
      async findAll() { return [{id:1, name:'电赛资料.pdf', contentSummary:'', extractedKeywords:[]}]; }
      async updateContentSummary() {} async markAsProcessed() { processed = true; }
      async updateCategory() { categoryWrites++; }
    }};
    if (id === '../data/vector/VectorStore') return {VectorStore: class {}};
    if (id === '../data/vector/VectorIndex') return {VectorIndex: class {}};
    if (id === '../data/repository/RagAnalysisLogRepository') return {RagAnalysisLogRepository: class {}};
    if (id === '../ai/model/EmbeddingModel') return {EmbeddingModel: class {isAvailable() {return false;}}};
    if (id === '../ai/KeywordExpansionService') return {SUPPORTED_CATEGORIES:['工作','学习'], KeywordExpansionService: class {async expand(words) {return words;}}};
    if (id === '../llm/LLMService') return {LLMService: class {static getInstance() {return {isConfigured:()=>true, analyzeFile:async()=>({summary:'summary', keywords:['study'], suggestedCategory:'学习'})};}}};
    if (id === '@ohos.file.fs' || id === '@ohos.data.relationalStore') return {};
  }
  if (id === '@kit.NetworkKit') return { http: { RequestMethod: { POST: 'POST' }, HttpDataType: { STRING: 0 }, createHttp: () => ({ request: async (url, options) => { sent = {url, body: JSON.parse(options.extraData)}; return reply; }, destroy: () => destroyed++ }) } };
  if (id === '@kit.UniversalKeystoreKit') return { huks: {
    HuksTag: {}, HuksKeyAlg: {}, HuksKeySize: {}, HuksKeyPurpose: {}, HuksKeyPadding: {}, HuksCipherMode: {},
    isKeyItemExist: async () => { if (keyLookupError) throw {code:keyLookupError}; if (!keyExists) throw {code:12000011}; return true; },
    generateKeyItem: async () => { generations++; keyExists = true; },
    initSession: async () => ({ handle: 1 }), finishSession: async () => ({ outData: new Uint8Array(24) })
  } };
  if (id === '@kit.CryptoArchitectureKit') return {cryptoFramework: {createRandom: () => ({generateRandomSync: n => ({data: new Uint8Array(n)})})}};
  if (id === '@kit.MindSporeLiteKit') return { mindSporeLite: { DataType: { NUMBER_TYPE_INT32:34, NUMBER_TYPE_INT64:35 } } };
  if (id === '@ohos.util' || id === '@ohos.data.preferences') return {};
  return original.call(this, id, ...rest);
};
(async () => {
 const { resolveLLMEndpoint, describeLLMError } = require('../entry/src/main/ets/llm/OpenAIClient.ets');
 const manifest = fs.readFileSync(path.join(__dirname, '../entry/src/main/module.json5'), 'utf8');
 assert.match(manifest, /ohos\.permission\.INTERNET/);
 assert.equal(resolveLLMEndpoint('https://gateway.example/v1/responses/', 'auto'), 'https://gateway.example/v1/responses');
 assert.throws(() => resolveLLMEndpoint('https://gateway.example/v1/responses', 'chat_completions'), /协议/);
 assert.match(describeLLMError(Object.assign(new Error('timeout'), {code:2300028})), /超时/);
 const {ReviewSuggestionService} = require('../entry/src/main/ets/service/ReviewSuggestionService.ets');
 const reviews = new ReviewSuggestionService();
 reviews.add({id:'old', fileId:1, fileName:'fixture.txt', suggestedCategory:'工作', confidence:0.4, reason:'old'});
 reviews.add({id:'new', fileId:1, fileName:'fixture.txt', suggestedCategory:'学习', confidence:0.8, reason:'new'});
 assert.equal(reviews.listPending().length, 1);
 assert.equal(reviews.listPending()[0].id, 'new');
 assert.equal(reviews.accept('new'), true);
 assert.equal(reviews.listPending().length, 0);
 const { encryptSecret } = require('../entry/src/main/ets/llm/LLMSecretStore.ets');
 await encryptSecret('fake-one'); await encryptSecret('fake-two');
 assert.equal(generations, 1, 'saving again must preserve encryption key');
 keyLookupError = 12000005;
 await assert.rejects(() => encryptSecret('fake-three'), error => error.message.includes('12000005'));
 assert.equal(generations, 1, 'unexpected keystore errors must not create or overwrite keys');
 keyLookupError = 0;
 const {tokenTensorData} = require('../entry/src/main/ets/ai/model/EmbeddingModel.ets');
 assert.deepEqual([...new Int32Array(tokenTensorData([101, 102], 34))], [101, 102]);
 assert.deepEqual([...new BigInt64Array(tokenTensorData([101, 102], 35))], [101n, 102n]);
 assert.throws(() => tokenTensorData([101], 43), /Unsupported/);
 isolateRag = true;
 const {RagAnalysisService} = require('../entry/src/main/ets/service/RagAnalysisService.ets');
 await new RagAnalysisService().processFile(1, 'fixture text');
 assert.equal(processed, true);
 const retrieval = await new RagAnalysisService().search('请根据已经检索到的所有文件仔细概括电赛');
 assert.equal(retrieval[0]?.file.id, 1, 'original query terms near the end must not be dropped by expansion limits');
 assert.equal(categoryWrites, 0, 'background enrichment must preserve rule/manual category');
 console.log('PASS: background enrichment preserves classification; latest review supersedes old suggestion');
 console.log('PASS: stable encryption key, INT32/INT64 token buffers');
 console.log('PASS: permission, endpoint validation and native error mapping (SDK protocol tests are separate)');
})().catch(error => { console.error(error); process.exitCode=1; });
